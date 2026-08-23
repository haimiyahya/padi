defmodule Padi.Router.InterrogationRouter do
  @moduledoc """
  JSON-RPC 2.0 Interrogation Router for Padi.

  This GenServer handles JSON-RPC method calls and dispatches them to
  the appropriate handlers. It supports:

  - codebase/query_intent - Query the codebase about capabilities
  - codebase/submit_mutation - Submit a code change
  - codebase/get_status - Get mutation status
  - codebase/list_symbols - List symbols in the codebase
  - codebase/get_history - Get git history

  The router integrates with:
  - LadybugNif for graph queries
  - VectorStore for semantic search
  - TreeSitter for AST operations
  - CodeWriter for mutations
  - MemGit for history
  """

  use GenServer
  require Logger

  alias Padi.Storage.{LadybugNif, VectorStore, MemGit}
  alias Padi.Parser.TreeSitter
  alias Padi.Coordinator.CodeWriter
  alias Padi.Compiler.TestImpact

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Start the Interrogation Router.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Handle a JSON-RPC method call.

  Returns {:ok, response_envelope} or {:error, reason}
  """
  def handle_method(method, params, id) do
    GenServer.call(__MODULE__, {:handle_method, method, params, id})
  end

  @doc """
  Send a response to the client.
  """
  def send_response(id, result) do
    response = Padi.Protocol.Messages.response_envelope(id, result)
    Padi.Router.StdioHandler.write_response(response)
  end

  @doc """
  Send an error response to the client.
  """
  def send_error(id, code, message, data \\ nil) do
    Padi.Router.StdioHandler.write_error(id, code, message, data)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    Logger.debug("InterrogationRouter initialized")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:handle_method, method, params, id}, _from, state) do
    Logger.debug("Handling method: #{method}")

    result = do_handle_method(method, params, id)

    case result do
      {:ok, response} -> {:reply, {:ok, response}, state}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  # ============================================================================
  # Method Handlers
  # ============================================================================

  defp do_handle_method("codebase/query_intent", params, id) do
    handle_codebase_query(params, id)
  end

  defp do_handle_method("codebase/submit_mutation", params, id) do
    handle_submit_mutation(params, id)
  end

  defp do_handle_method("codebase/get_status", params, id) do
    handle_get_status(params, id)
  end

  defp do_handle_method("codebase/list_symbols", params, id) do
    handle_list_symbols(params, id)
  end

  defp do_handle_method("codebase/get_history", params, id) do
    handle_get_history(params, id)
  end

  defp do_handle_method(method, _params, id) do
    # Unknown method
    {:ok, Padi.Protocol.Messages.error_envelope(id, -32601, "Method not found: #{method}")}
  end

  # ============================================================================
  # Method Implementations
  # ============================================================================

  defp handle_codebase_query(params, id) do
    intent = Map.get(params, "intent_description", "")
    target_spec = Map.get(params, "target_spec_id")

    Logger.debug("Query intent: #{intent}")

    # Use vector search to find similar functions
    case generate_embedding(intent) do
      {:ok, embedding} ->
        case VectorStore.search_by_intent(embedding, 5) do
          {:ok, %{"results" => results}} when length(results) > 0 ->
            # Found similar existing code
            top_result = Enum.at(results, 0)
            node_id = Map.get(top_result, "node_id")

            case get_detailed_symbol_info(node_id) do
              {:ok, symbol_info} ->
                response = %{
                  "status" => "found_existing",
                  "recommendation" => "Extend existing functionality",
                  "current_symbol" => symbol_info,
                  "similar_functions" => results,
                  "historical_context" => get_historical_context(node_id),
                  "codebase_guideline_template" => get_template_for_symbol(symbol_info)
                }

                {:ok, Padi.Protocol.Messages.response_envelope(id, response)}

              {:error, _} ->
                response = %{
                  "status" => "found_existing",
                  "recommendation" => "Similar code exists",
                  "similar_functions" => results
                }

                {:ok, Padi.Protocol.Messages.response_envelope(id, response)}
            end

          {:ok, %{"results" => []}} ->
            # No similar code found - new feature
            response = %{
              "status" => "new_feature",
              "recommendation" => "Create new functionality",
              "suggested_location" => suggest_location(intent)
            }

            {:ok, Padi.Protocol.Messages.response_envelope(id, response)}
        end

      {:error, _reason} ->
        # Fallback to Cypher query
        response = %{
          "status" => "new_feature",
          "recommendation" => "Create new functionality"
        }

        {:ok, Padi.Protocol.Messages.response_envelope(id, response)}
    end
  end

  defp handle_submit_mutation(params, id) do
    ast_node_id = Map.get(params, "ast_node_id")
    target_file = Map.get(params, "target_file")
    proposed_patch = Map.get(params, "proposed_patch")

    Logger.debug("Submit mutation: #{target_file}")

    # Submit to CodeWriter
    request = Padi.Coordinator.MutationRequest.new(
      target_file,
      proposed_patch,
      ast_node_id: ast_node_id,
      caller_pid: self()
    )

    case CodeWriter.submit_mutation(request) do
      {:ok, result} ->
        response = %{
          "request_id" => request.request_id,
          "status" => "success",
          "test_results" => Map.get(result, :test_results, %{})
        }

        {:ok, Padi.Protocol.Messages.response_envelope(id, response)}

      {:rejected, details} ->
        # Policy violation
        violations = Map.get(details, :violations, [])

        error_data = case Enum.at(violations, 0) do
          nil -> %{"reason" => "unknown"}
          violation ->
            %{
              "rule_id" => Map.get(violation, :rule_id),
              "rule_name" => Map.get(violation, :rule_name),
              "reason" => Map.get(violation, :reason),
              "suggested_fix" => Map.get(violation, :recommendation)
            }
        end

        {:ok, Padi.Protocol.Messages.error_envelope(
          id,
          -32001,
          "Mutation rejected by pre-flight AST policy",
          error_data
        )}

      {:error, reason} ->
        {:ok, Padi.Protocol.Messages.error_envelope(
          id,
          -32003,
          "Mutation failed: #{inspect(reason)}"
        )}
    end
  end

  defp handle_get_status(params, id) do
    request_id = Map.get(params, "request_id")

    case CodeWriter.get_status(request_id) do
      {:ok, status} ->
        response = Map.put(status, :request_id, request_id)
        {:ok, Padi.Protocol.Messages.response_envelope(id, response)}

      {:error, :not_found} ->
        {:ok, Padi.Protocol.Messages.error_envelope(
          id,
          -32002,
          "Request not found"
        )}
    end
  end

  defp handle_list_symbols(params, id) do
    pattern = Map.get(params, "pattern")
    file_pattern = Map.get(params, "file_pattern")
    symbol_types = Map.get(params, "symbol_types", [])

    # Query the knowledge graph for matching symbols
    query = build_symbols_query(pattern, file_pattern, symbol_types)

    case LadybugNif.execute_cypher(query, %{}) do
      {:ok, %{"rows" => rows}} ->
        symbols = Enum.map(rows, fn row ->
          %{
            "id" => get_in(row, ["n", "id"]),
            "filepath" => get_in(row, ["n", "filepath"]),
            "line" => get_in(row, ["n", "start_line"]),
            "symbol_name" => get_in(row, ["n", "symbol_name"]),
            "symbol_type" => get_in(row, ["n", "node_type"])
          }
        end)

        response = %{"symbols" => symbols}
        {:ok, Padi.Protocol.Messages.response_envelope(id, response)}

      {:error, _reason} ->
        response = %{"symbols" => []}
        {:ok, Padi.Protocol.Messages.response_envelope(id, response)}
    end
  end

  defp handle_get_history(params, id) do
    target = Map.get(params, "target")
    limit = Map.get(params, "limit", 10)

    # Get history from MemGit
    case String.contains?(target, ":") do
      true ->
        # AST node ID
        case MemGit.get_lineage(target) do
          {:ok, commits} ->
            limited = Enum.take(commits, limit)
            response = %{"commits" => limited}
            {:ok, Padi.Protocol.Messages.response_envelope(id, response)}

          {:error, _reason} ->
            response = %{"commits" => []}
            {:ok, Padi.Protocol.Messages.response_envelope(id, response)}
        end

      false ->
        # File path
        case MemGit.get_file_history(target) do
          {:ok, commits} ->
            limited = Enum.take(commits, limit)
            response = %{"commits" => limited}
            {:ok, Padi.Protocol.Messages.response_envelope(id, response)}

          {:error, _reason} ->
            response = %{"commits" => []}
            {:ok, Padi.Protocol.Messages.response_envelope(id, response)}
        end
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp generate_embedding(text) do
    # In a full implementation, this would use an embedding model
    # For now, return a placeholder embedding
    {:ok, List.duplicate(0.0, 1536)}
  end

  defp get_detailed_symbol_info(node_id) do
    case LadybugNif.get_node(node_id) do
      {:ok, node} ->
        # Get callers
        callers_query = """
        MATCH (caller:ASTNode)-[:CALLS]->(n:ASTNode {id: $node_id})
        RETURN caller.filepath AS file, caller.start_line AS line
        LIMIT 10
        """

        callers = case LadybugNif.execute_cypher(callers_query, %{node_id: node_id}) do
          {:ok, %{"rows" => rows}} ->
            Enum.map(rows, fn %{"file" => file, "line" => line} ->
              %{file: file, line: line}
            end)

          _ ->
            []
        end

        {:ok, %{
          "node_id" => Map.get(node, "id"),
          "filepath" => Map.get(node, "filepath"),
          "line_start" => Map.get(node, "start_line"),
          "symbol_name" => Map.get(node, "symbol_name"),
          "node_type" => Map.get(node, "node_type"),
          "affected_callers" => callers
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_historical_context(node_id) do
    case MemGit.get_lineage(node_id) do
      {:ok, [commit | _]} ->
        "Created by #{commit.author} in commit #{String.slice(commit.hash, 0..6)}"

      {:ok, []} ->
        "No history available"

      {:error, _} ->
        "History unavailable"
    end
  end

  defp get_template_for_symbol(symbol_info) do
    # Generate a code template based on the symbol type
    case Map.get(symbol_info, "node_type") do
      "function_definition" ->
        "def function_name(arg1, arg2) do\n  # Implementation\nend"

      "module" ->
        "defmodule ModuleName do\n  # Implementation\nend"

      _ ->
        "# Code template"
    end
  end

  defp suggest_location(intent) do
    # Simple heuristic for suggesting a file location
    cond do
      String.contains?(intent, ["test", "spec"]) ->
        "test/"

      String.contains?(intent, ["auth", "user", "login"]) ->
        "lib/auth/"

      String.contains?(intent, ["api", "controller", "route"]) ->
        "lib/api/"

      true ->
        "lib/"
    end
  end

  defp build_symbols_query(pattern, file_pattern, symbol_types) do
    # Build a Cypher query for symbol search
    base = "MATCH (n:ASTNode) WHERE "

    conditions = []

    conditions = if pattern, do: ["n.symbol_name CONTAINS '#{pattern}'" | conditions], else: conditions
    conditions = if file_pattern, do: ["n.filepath CONTAINS '#{file_pattern}'" | conditions], else: conditions
    conditions = if length(symbol_types) > 0, do: ["n.node_type IN #{inspect(symbol_types)}" | conditions], else: conditions

    where = case conditions do
      [] -> "true"
      con -> Enum.join(con, " AND ")
    end

    base <> where <> " RETURN n LIMIT 100"
  end
end

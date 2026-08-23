defmodule Padi.Compiler.TestImpact do
  @moduledoc """
  Targeted Test Impact Analysis using graph traversal.

  Instead of running the entire test suite, this module calculates
  the exact "blast radius" of a code change and runs only the
  relevant tests.

  This enables:
  - Sub-20ms targeted test execution
  - Fast feedback for code changes
  - Efficient CI/CD pipelines

  The analysis uses the knowledge graph to trace:
  1. Direct test-to-node relationships ([:EXERCISES])
  2. Transitive call graph relationships ([:CALLS])
  """

  use GenServer
  require Logger

  alias Padi.Storage.LadybugNif

  # Public API

  @doc """
  Start the Test Impact Analysis server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Calculate the impact radius for an AST node.

  Returns the set of tests that would be affected by changing this node.
  """
  def calculate_impact_radius(ast_node_id, depth \\ 3) do
    GenServer.call(__MODULE__, {:calculate_impact_radius, ast_node_id, depth})
  end

  @doc """
  Find all tests that exercise a given AST node.
  """
  def find_exercising_tests(ast_node_id) do
    GenServer.call(__MODULE__, {:find_exercising_tests, ast_node_id})
  end

  @doc """
  Get all tests affected by changes to the given AST nodes.
  """
  def get_affected_tests(ast_node_ids) when is_list(ast_node_ids) do
    GenServer.call(__MODULE__, {:get_affected_tests, ast_node_ids})
  end

  @doc """
  Trace the call graph from an AST node to find what it calls.
  """
  def trace_call_graph(ast_node_id) do
    GenServer.call(__MODULE__, {:trace_call_graph, ast_node_id})
  end

  @doc """
  Trace the reverse call graph to find what calls this node.
  """
  def trace_reverse_call_graph(ast_node_id) do
    GenServer.call(__MODULE__, {:trace_reverse_call_graph, ast_node_id})
  end

  @doc """
  Calculate test priority based on impact and historical failure rates.
  """
  def calculate_test_priority(tests) when is_list(tests) do
    GenServer.call(__MODULE__, {:calculate_test_priority, tests})
  end

  @doc """
  Get the impact graph for visualization.
  """
  def get_impact_graph(ast_node_id) do
    GenServer.call(__MODULE__, {:get_impact_graph, ast_node_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      cache: %{},
      stats: %{
        analyses: 0,
        cache_hits: 0
      }
    }

    Logger.debug("TestImpact initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:calculate_impact_radius, ast_node_id, depth}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result = do_calculate_impact_radius(ast_node_id, depth)

    duration = System.monotonic_time(:microsecond) - start_time
    Logger.debug("Impact radius calculation took #{duration}μs")

    new_stats = Map.update!(state.stats, :analyses, &(&1 + 1))

    # Cache the result
    new_cache = Map.put(state.cache, {ast_node_id, depth}, %{
      result: result,
      timestamp: System.monotonic_time()
    })

    {:reply, {:ok, result}, %{state | stats: new_stats, cache: new_cache}}
  end

  @impl true
  def handle_call({:find_exercising_tests, ast_node_id}, _from, state) do
    case LadybugNif.find_exercising_tests(ast_node_id) do
      {:ok, %{"rows" => test_rows}} ->
        tests = Enum.map(test_rows, fn row ->
          extract_test_info(row)
        end)

        new_stats = Map.update!(state.stats, :analyses, &(&1 + 1))
        {:reply, {:ok, tests}, %{state | stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_affected_tests, ast_node_ids}, _from, state) do
    case LadybugNif.find_affected_tests(ast_node_ids) do
      {:ok, %{"rows" => test_rows}} ->
        tests = Enum.map(test_rows, fn row ->
          extract_test_info(row)
        end)

        new_stats = Map.update!(state.stats, :analyses, &(&1 + 1))
        {:reply, {:ok, tests}, %{state | stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:trace_call_graph, ast_node_id}, _from, state) do
    result = do_trace_call_graph(ast_node_id, :outbound)
    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call({:trace_reverse_call_graph, ast_node_id}, _from, state) do
    result = do_trace_call_graph(ast_node_id, :inbound)
    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call({:calculate_test_priority, tests}, _from, state) do
    prioritized = Enum.map(tests, fn test ->
      priority = calculate_single_test_priority(test)
      Map.put(test, :priority, priority)
    end)

    # Sort by priority
    sorted = Enum.sort(prioritized, fn a, b ->
      a.priority > b.priority
    end)

    {:reply, {:ok, sorted}, state}
  end

  @impl true
  def handle_call({:get_impact_graph, ast_node_id}, _from, state) do
    # Build a graph structure for visualization
    graph = build_impact_graph(ast_node_id)
    {:reply, {:ok, graph}, state}
  end

  # Private helpers

  defp do_calculate_impact_radius(ast_node_id, depth) do
    # Calculate the full impact radius including:
    # 1. Direct tests exercising this node
    # 2. Tests exercising nodes this node calls
    # 3. Tests exercising nodes that call this node

    # Get direct tests
    direct_tests = case LadybugNif.find_exercising_tests(ast_node_id) do
      {:ok, %{"rows" => rows}} ->
        Enum.map(rows, &extract_test_info/1)

      _ ->
        []
    end

    # Get call graph
    called_nodes = get_called_nodes(ast_node_id, depth)
    caller_nodes = get_caller_nodes(ast_node_id, depth)

    # Get tests for called nodes
    called_tests = get_tests_for_nodes(called_nodes)

    # Get tests for caller nodes
    caller_tests = get_tests_for_nodes(caller_nodes)

    # Combine and deduplicate
    all_tests = (direct_tests ++ called_tests ++ caller_tests)
      |> Enum.uniq_by(fn t -> t.id end)

    %{
      direct: direct_tests,
      transitive_called: called_tests,
      transitive_caller: caller_tests,
      all: all_tests,
      called_nodes: called_nodes,
      caller_nodes: caller_nodes
    }
  end

  defp get_called_nodes(node_id, depth) do
    # Trace outbound call graph
    query = """
    MATCH (n:ASTNode {id: $node_id})-[:CALLS*1..#{depth}]->(called:ASTNode)
    RETURN DISTINCT called.id AS id
    """

    case LadybugNif.execute_cypher(query, %{node_id: node_id}) do
      {:ok, %{"rows" => rows}} ->
        Enum.map(rows, fn %{"id" => id} -> id end)

      _ ->
        []
    end
  end

  defp get_caller_nodes(node_id, depth) do
    # Trace inbound call graph
    query = """
    MATCH (caller:ASTNode)-[:CALLS*1..#{depth}]->(n:ASTNode {id: $node_id})
    RETURN DISTINCT caller.id AS id
    """

    case LadybugNif.execute_cypher(query, %{node_id: node_id}) do
      {:ok, %{"rows" => rows}} ->
        Enum.map(rows, fn %{"id" => id} -> id end)

      _ ->
        []
    end
  end

  defp get_tests_for_nodes(node_ids) when is_list(node_ids) do
    case LadybugNif.find_affected_tests(node_ids) do
      {:ok, %{"rows" => rows}} ->
        Enum.map(rows, &extract_test_info/1)

      _ ->
        []
    end
  end

  defp do_trace_call_graph(node_id, direction) do
    dir_str = case direction do
      :outbound -> "OUTBOUND"
      :inbound -> "INBOUND"
      _ -> "BOTH"
    end

    query = case direction do
      :outbound ->
        "MATCH (n:ASTNode {id: $node_id})-[:CALLS]->(called:ASTNode) RETURN called"

      :inbound ->
        "MATCH (caller:ASTNode)-[:CALLS]->(n:ASTNode {id: $node_id}) RETURN caller"
    end

    case LadybugNif.execute_cypher(query, %{node_id: node_id}) do
      {:ok, %{"rows" => rows}} ->
        Enum.map(rows, fn row ->
          extract_node_info(row, direction)
        end)

      _ ->
        []
    end
  end

  defp extract_node_info(row, direction) do
    node = case direction do
      :outbound -> get_in(row, ["called"])
      :inbound -> get_in(row, ["caller"])
    end

    %{
      id: node["id"],
      filepath: node["filepath"],
      symbol_name: node["symbol_name"],
      node_type: node["node_type"]
    }
  end

  defp extract_test_info(row) do
    test = case row do
      %{"t" => test_node} -> test_node
      test_map when is_map(test_map) -> test_map
    end

    %{
      id: test["id"],
      filepath: test["filepath"],
      test_name: test["test_name"],
      framework: test["framework"] || "unknown"
    }
  end

  defp calculate_single_test_priority(test) do
    # Priority factors:
    # 1. Historical failure rate (higher = more priority)
    # 2. Execution time (faster tests = more priority for quick feedback)
    # 3. Test breadth (tests that cover more = more priority)

    failure_rate = Map.get(test, :failure_rate, 0.0)
    duration = Map.get(test, :duration_ms, 10)
    coverage = Map.get(test, :coverage_count, 1)

    # Calculate priority score (0-100)
    score = (failure_rate * 50) + (1000 / max(duration, 1)) + (coverage * 2)
    min(score, 100)
  end

  defp build_impact_graph(ast_node_id) do
    # Build a graph structure for visualization
    radius = do_calculate_impact_radius(ast_node_id, 2)

    %{
      center: ast_node_id,
      nodes: [
        %{id: ast_node_id, type: :center, label: "Changed Node"}
        | Enum.map(radius.called_nodes, &%{id: &1, type: :called, label: "Called"}) ++
          Enum.map(radius.caller_nodes, &%{id: &1, type: :caller, label: "Called By"})
      ],
      edges: build_edge_list(ast_node_id, radius)
    }
  end

  defp build_edge_list(center_id, radius) do
    # Build edges for the graph
    called_edges = Enum.map(radius.called_nodes, fn node_id ->
      %{from: center_id, to: node_id, type: :calls}
    end)

    caller_edges = Enum.map(radius.caller_nodes, fn node_id ->
      %{from: node_id, to: center_id, type: :called_by}
    end)

    test_edges = Enum.map(radius.all, fn test ->
      %{from: test.id, to: center_id, type: :exercises}
    end)

    called_edges ++ caller_edges ++ test_edges
  end
end

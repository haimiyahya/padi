defmodule Padi.Protocol.Messages do
  @moduledoc """
  JSON-RPC 2.0 protocol message types for Padi.

  These structs define the request and response messages used for
  communication between AI agents/developers and the Padi harness.

  Protocol: JSON-RPC 2.0
  Transport: stdin/stdout, WebSockets, or Unix Domain Socket
  """

  # ============================================================================
  # Request Types
  # ============================================================================

  defmodule QueryIntentRequest do
    @moduledoc """
    Request to query the codebase about its capabilities.

    The agent provides an intent description (in natural language) and
    optionally a target spec ID. The harness responds with:
    - Whether similar functionality exists
    - Current symbols that match the intent
    - Affected callers
    - Historical context
    - Code template recommendations
    """

    defstruct [:intent_description, :target_spec_id]

    @type t :: %__MODULE__{
      intent_description: String.t(),
      target_spec_id: String.t() | nil
    }

    @doc """
    Create a new query intent request.
    """
    def new(intent_description, opts \\ []) do
      %__MODULE__{
        intent_description: intent_description,
        target_spec_id: Keyword.get(opts, :target_spec_id)
      }
    end
  end

  defmodule SubmitMutationRequest do
    @moduledoc """
    Request to submit a code mutation.

    The agent provides:
    - The AST node ID to modify (optional)
    - The target file path
    - The proposed patch (full file content or diff)

    The harness validates the patch and either accepts or rejects it.
    """

    defstruct [:ast_node_id, :target_file, :proposed_patch]

    @type t :: %__MODULE__{
      ast_node_id: String.t() | nil,
      target_file: String.t(),
      proposed_patch: String.t()
    }

    @doc """
    Create a new submit mutation request.
    """
    def new(target_file, proposed_patch, opts \\ []) do
      %__MODULE__{
        target_file: target_file,
        proposed_patch: proposed_patch,
        ast_node_id: Keyword.get(opts, :ast_node_id)
      }
    end
  end

  defmodule GetStatusRequest do
    @moduledoc """
    Request to get the status of a mutation request.
    """

    defstruct [:request_id]

    @type t :: %__MODULE__{
      request_id: String.t()
    }
  end

  defmodule ListSymbolsRequest do
    @moduledoc """
    Request to list symbols in the codebase.
    """

    defstruct [:pattern, :file_pattern, :symbol_types]

    @type t :: %__MODULE__{
      pattern: String.t() | nil,
      file_pattern: String.t() | nil,
      symbol_types: [String.t()] | nil
    }
  end

  defmodule GetHistoryRequest do
    @moduledoc """
    Request to get git history for a file or AST node.
    """

    defstruct [:target, :limit]

    @type t :: %__MODULE__{
      target: String.t(),
      limit: integer() | nil
    }
  end

  # ============================================================================
  # Response Types
  # ============================================================================

  defmodule QueryIntentResponse do
    @moduledoc """
    Response to a query intent request.

    Provides the agent with actionable information about existing
    code and recommendations for how to proceed.
    """

    defstruct [
      :status,
      :recommendation,
      :current_symbol,
      :affected_callers,
      :historical_context,
      :codebase_guideline_template
    ]

    @type t :: %__MODULE__{
      status: :found_existing | :new_feature | :not_found,
      recommendation: String.t(),
      current_symbol: symbol_info() | nil,
      affected_callers: [caller_info()] | nil,
      historical_context: String.t() | nil,
      codebase_guideline_template: String.t() | nil
    }

    @type symbol_info :: %{
      node_id: String.t(),
      filepath: String.t(),
      line_start: integer(),
      current_algorithm: String.t() | nil
    }

    @type caller_info :: %{
      file: String.t(),
      line: integer()
    }
  end

  defmodule SubmitMutationResponse do
    @moduledoc """
    Response to a successful mutation submission.
    """

    defstruct [:request_id, :status, :test_results, :errors, :warnings]

    @type t :: %__MODULE__{
      request_id: String.t(),
      status: :success,
      test_results: test_results(),
      errors: [String.t()],
      warnings: [String.t()]
    }

    @type test_results :: %{
      passed: [String.t()],
      failed: [String.t()],
      duration_us: integer()
    }
  end

  defmodule MutationRejectedResponse do
    @moduledoc """
    Response when a mutation is rejected by the pre-flight policy checker.
    """

    defstruct [:request_id, :rule_id, :rule_name, :reason, :failing_ast_node, :suggested_fix]

    @type t :: %__MODULE__{
      request_id: String.t(),
      rule_id: String.t(),
      rule_name: String.t(),
      reason: String.t(),
      failing_ast_node: String.t() | nil,
      suggested_fix: String.t()
    }
  end

  defmodule StatusResponse do
    @moduledoc """
    Response to a status request.
    """

    defstruct [:request_id, :status, :state]

    @type t :: %__MODULE__{
      request_id: String.t(),
      status: :queued | :processing | :completed | :failed,
      state: String.t() | nil
    }
  end

  defmodule ListSymbolsResponse do
    @moduledoc """
    Response to a list symbols request.
    """

    defstruct [:symbols]

    @type t :: %__MODULE__{
      symbols: [symbol_info()]
    }

    @type symbol_info :: %{
      id: String.t(),
      filepath: String.t(),
      line: integer(),
      symbol_name: String.t(),
      symbol_type: String.t()
    }
  end

  defmodule HistoryResponse do
    @moduledoc """
    Response to a history request.
    """

    defstruct [:commits]

    @type t :: %__MODULE__{
      commits: [commit_info()]
    }

    @type commit_info :: %{
      hash: String.t(),
      author: String.t(),
      message: String.t(),
      timestamp: integer()
    }
  end

  # ============================================================================
  # Error Response Types
  # ============================================================================

  defmodule ErrorResponse do
    @moduledoc """
    Standard JSON-RPC error response.
    """

    defstruct [:code, :message, :data]

    @type t :: %__MODULE__{
      code: integer(),
      message: String.t(),
      data: map() | nil
    }

    # Standard JSON-RPC error codes
    def parse_error, do: -32700
    def invalid_request, do: -32600
    def method_not_found, do: -32601
    def invalid_params, do: -32602
    def internal_error, do: -32603

    # Padi-specific error codes
    def mutation_rejected, do: -32001
    def file_locked, do: -32002
    def policy_violation, do: -32003
    def test_failure, do: -32004
    def parse_error, do: -32005
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  @doc """
  Create a JSON-RPC request envelope.
  """
  def request_envelope(id, method, params) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => method,
      "params" => params
    }
  end

  @doc """
  Create a JSON-RPC response envelope.
  """
  def response_envelope(id, result) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => result
    }
  end

  @doc """
  Create a JSON-RPC error envelope.
  """
  def error_envelope(id, code, message, data \\ nil) do
    error = %{
      "code" => code,
      "message" => message
    }

    error = if data, do: Map.put(error, "data", data), else: error

    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => error
    }
  end

  @doc """
  Parse a JSON-RPC request.
  """
  def parse_request(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, data} -> parse_request(data)
      {:error, _} -> {:error, :parse_error}
    end
  end

  def parse_request(data) when is_map(data) do
    cond do
      not Map.has_key?(data, "jsonrpc") ->
        {:error, :invalid_request}

      data["jsonrpc"] != "2.0" ->
        {:error, :invalid_request}

      not Map.has_key?(data, "method") ->
        {:error, :invalid_request}

      true ->
        {:ok, %{
          id: Map.get(data, "id"),
          method: data["method"],
          params: Map.get(data, "params", %{})
        }}
    end
  end

  @doc """
  Encode a response to JSON.
  """
  def encode_response(response) do
    Jason.encode!(response)
  end
end

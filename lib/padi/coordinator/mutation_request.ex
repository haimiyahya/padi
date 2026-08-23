defmodule Padi.Coordinator.MutationRequest do
  @moduledoc """
  Struct representing a code mutation request.

  This is the primary data structure for requests to the CodeWriter
  single-writer coordinator.
  """

  @type t :: %__MODULE__{
    request_id: String.t(),
    target_file: Path.t(),
    ast_node_id: String.t() | nil,
    proposed_patch: String.t(),
    caller_pid: pid() | nil,
    timestamp: integer(),
    priority: atom(),
    metadata: map()
  }

  defstruct [
    :request_id,
    :target_file,
    :ast_node_id,
    :proposed_patch,
    :caller_pid,
    :timestamp,
    :priority,
    :metadata
  ]

  @doc """
  Create a new mutation request.

  ## Options
  - :ast_node_id - The ID of the AST node to modify (if applicable)
  - :caller_pid - The PID of the requesting process
  - :priority - Request priority (:normal, :high, :urgent)
  - :metadata - Additional metadata
  """
  def new(target_file, proposed_patch, opts \\ []) do
    %__MODULE__{
      request_id: generate_request_id(),
      target_file: target_file,
      ast_node_id: Keyword.get(opts, :ast_node_id),
      proposed_patch: proposed_patch,
      caller_pid: Keyword.get(opts, :caller_pid),
      timestamp: System.monotonic_time(:millisecond),
      priority: Keyword.get(opts, :priority, :normal),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Generate a unique request ID.
  """
  def generate_request_id do
    "req_" <> :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  @doc """
  Check if the request is high priority.
  """
  def high_priority?(%__MODULE__{priority: :high}), do: true
  def high_priority?(%__MODULE__{priority: :urgent}), do: true
  def high_priority?(%__MODULE__{}), do: false

  @doc """
  Get the age of the request in milliseconds.
  """
  def age(%__MODULE__{timestamp: ts}) do
    System.monotonic_time(:millisecond) - ts
  end

  @doc """
  Check if the request has timed out.
  """
  def timed_out?(%__MODULE__{} = req, timeout_ms \\ 30_000) do
    age(req) > timeout_ms
  end
end

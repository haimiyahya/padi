defmodule Padi.Parser.ASTNode do
  @moduledoc """
  AST Node struct representing a node in the parsed syntax tree.

  This struct is used throughout the system to represent:
  - Functions, classes, modules
  - Statements and expressions
  - Any other syntactic construct

  Each node has a unique ID and can be linked to:
  - Its parent and children nodes
  - Functions it calls
  - Commits that modified it
  - Tests that exercise it
  """

  @type t :: %__MODULE__{
    id: String.t(),
    filepath: Path.t(),
    start_line: pos_integer(),
    end_line: pos_integer(),
    symbol_name: String.t() | nil,
    node_type: atom(),
    parent_id: String.t() | nil,
    children_ids: [String.t()],
    calls: [String.t()],
    called_by: [String.t()],
    metadata: map()
  }

  defstruct [
    :id,
    :filepath,
    :start_line,
    :end_line,
    :symbol_name,
    :node_type,
    :parent_id,
    :children_ids,
    :calls,
    :called_by,
    :metadata
  ]

  @doc """
  Create a new AST node.

  ## Options
  - :symbol_name - The name of the symbol (function name, class name, etc.)
  - :node_type - The type of node (e.g., :function_definition, :class, :module)
  - :parent_id - The ID of the parent node
  - :metadata - Additional metadata about the node
  """
  def new(filepath, start_line, end_line, opts \\ []) do
    id = generate_node_id(filepath, start_line, opts)

    struct(__MODULE__, [
      id: id,
      filepath: filepath,
      start_line: start_line,
      end_line: end_line,
      symbol_name: Keyword.get(opts, :symbol_name),
      node_type: Keyword.get(opts, :node_type, :unknown),
      parent_id: Keyword.get(opts, :parent_id),
      children_ids: Keyword.get(opts, :children_ids, []),
      calls: Keyword.get(opts, :calls, []),
      called_by: Keyword.get(opts, :called_by, []),
      metadata: Keyword.get(opts, :metadata, %{})
    ])
  end

  @doc """
  Generate a unique node ID from filepath and position.
  """
  def generate_node_id(filepath, start_line, opts) do
    symbol = Keyword.get(opts, :symbol_name, "anon")
    sanitized_path = String.replace(filepath, "/", "_")
    "#{sanitized_path}:#{start_line}:#{symbol}"
  end

  @doc """
  Add a child node ID to this node.
  """
  def add_child(%__MODULE__{} = node, child_id) do
    %{node | children_ids: [child_id | node.children_ids]}
  end

  @doc """
  Add a call relationship to this node.
  """
  def add_call(%__MODULE__{} = node, callee_id) do
    %{node | calls: [callee_id | node.calls]}
  end

  @doc """
  Add a "called by" relationship to this node.
  """
  def add_called_by(%__MODULE__{} = node, caller_id) do
    %{node | called_by: [caller_id | node.called_by]}
  end

  @doc """
  Get the range of this node as a string.
  """
  def range_string(%__MODULE__{start_line: s, end_line: e}) when s == e, do: "L#{s}"
  def range_string(%__MODULE__{start_line: s, end_line: e}), do: "L#{s}-L#{e}"

  @doc """
  Check if this node overlaps with another node.
  """
  def overlaps?(%__MODULE__{} = a, %__MODULE__{} = b) do
    not (a.end_line < b.start_line or a.start_line > b.end_line)
  end

  @doc """
  Check if this node contains a line.
  """
  def contains_line?(%__MODULE__{start_line: s, end_line: e}, line) do
    line >= s and line <= e
  end

  @doc """
  Create a node from a parsed AST result.
  """
  def from_ast_result(filepath, ast_result) do
    start_line = get_in(ast_result, ["range", "start", "row"]) || 0
    end_line = get_in(ast_result, ["range", "end", "row"]) || 0
    node_type = ast_result["type"] || :unknown

    new(filepath, start_line, end_line,
      symbol_name: get_symbol_name(ast_result),
      node_type: String.to_atom(node_type),
      metadata: %{"raw_ast" => ast_result}
    )
  end

  @doc """
  Convert node to a map for storage in the graph database.
  """
  def to_map(%__MODULE__{} = node) do
    %{
      id: node.id,
      filepath: node.filepath,
      start_line: node.start_line,
      end_line: node.end_line,
      symbol_name: node.symbol_name,
      node_type: to_string(node.node_type),
      parent_id: node.parent_id,
      children_ids: node.children_ids,
      calls: node.calls,
      called_by: node.called_by,
      metadata: node.metadata
    }
  end

  @doc """
  Create a node from a map retrieved from the graph database.
  """
  def from_map(map) when is_map(map) do
    struct(__MODULE__, %{
      id: map["id"] || map[:id],
      filepath: map["filepath"] || map[:filepath],
      start_line: map["start_line"] || map[:start_line],
      end_line: map["end_line"] || map[:end_line],
      symbol_name: map["symbol_name"] || map[:symbol_name],
      node_type: parse_node_type(map["node_type"] || map[:node_type]),
      parent_id: map["parent_id"] || map[:parent_id],
      children_ids: map["children_ids"] || map[:children_ids] || [],
      calls: map["calls"] || map[:calls] || [],
      called_by: map["called_by"] || map[:called_by] || [],
      metadata: map["metadata"] || map[:metadata] || %{}
    })
  end

  # Private helpers

  defp get_symbol_name(ast_result) do
    # Try to extract symbol name from various node types
    case ast_result["type"] do
      "function_definition" -> get_in(ast_result, ["name", "text"])
      "identifier" -> ast_result["text"]
      _ -> nil
    end
  end

  defp parse_node_type(nil), do: :unknown
  defp parse_node_type(type) when is_atom(type), do: type
  defp parse_node_type(type) when is_binary(type), do: String.to_atom(type)
end

defmodule Treepadi do
  @moduledoc """
  NIF loader for treepadi (Tree-sitter parser).
  """
  @on_load :load_nif

  def load_nif do
    nif_file = ~c"#{:code.priv_dir(:padi)}/native/libtreepadi"
    :erlang.load_nif(nif_file, 0)
  end

  # Fallback functions when NIF is not loaded
  def list_languages, do: raise "NIF not loaded"
  def load_language(_lang), do: raise "NIF not loaded"
  def detect_language(_filepath), do: raise "NIF not loaded"
  def parse_file(_filepath, _language), do: raise "NIF not loaded"
  def parse_string(_source, _language), do: raise "NIF not loaded"
  def get_ast_tree(_source, _language), do: raise "NIF not loaded"
  def get_node_type(_node_id), do: raise "NIF not loaded"
  def get_node_text(_node_id, _source), do: raise "NIF not loaded"
  def get_node_range(_node_id), do: raise "NIF not loaded"
  def get_node_children(_node_id), do: raise "NIF not loaded"
  def find_node_by_type(_tree_id, _node_type), do: raise "NIF not loaded"
  def find_node_by_position(_tree_id, _row, _column), do: raise "NIF not loaded"
  def extract_call_graph(_ast_id), do: raise "NIF not loaded"
  def extract_function_definitions(_ast_id), do: raise "NIF not loaded"
  def extract_function_calls(_node_id), do: raise "NIF not loaded"
end

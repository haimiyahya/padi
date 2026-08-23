defmodule Ladypadi do
  @moduledoc """
  NIF loader for ladypadi (LadybugDB graph database).
  """
  @on_load :load_nif

  def load_nif do
    nif_file = ~c"#{:code.priv_dir(:padi)}/native/libladypadi"
    :erlang.load_nif(nif_file, 0)
  end

  # Fallback functions when NIF is not loaded
  def open(_db_path), do: raise "NIF not loaded"
  def close, do: raise "NIF not loaded"
  def execute_cypher(_query, _params), do: raise "NIF not loaded"
  def create_node(_label, _properties), do: raise "NIF not loaded"
  def create_relationship(_from, _to, _type, _properties), do: raise "NIF not loaded"
  def get_node(_id), do: raise "NIF not loaded"
  def update_node(_id, _properties), do: raise "NIF not loaded"
  def delete_node(_id), do: raise "NIF not loaded"
  def get_relationships(_node_id, _direction), do: raise "NIF not loaded"
  def find_path(_from_id, _to_id, _max_depth), do: raise "NIF not loaded"
  def find_exercising_tests(_ast_node_id), do: raise "NIF not loaded"
  def find_affected_tests(_ast_node_ids), do: raise "NIF not loaded"
end

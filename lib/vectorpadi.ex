defmodule Vectorpadi do
  @moduledoc """
  NIF loader for vectorpadi (HNSW vector index).
  """
  @on_load :load_nif

  def load_nif do
    nif_file = ~c"#{:code.priv_dir(:padi)}/native/libvectorpadi"
    :erlang.load_nif(nif_file, 0)
  end

  # Fallback functions when NIF is not loaded
  def create_index(_dimension, _capacity), do: raise "NIF not loaded"
  def load_index(_path), do: raise "NIF not loaded"
  def save_index(_path), do: raise "NIF not loaded"
  def clear, do: raise "NIF not loaded"
  def insert(_id, _vector), do: raise "NIF not loaded"
  def insert_batch(_entries), do: raise "NIF not loaded"
  def remove(_id), do: raise "NIF not loaded"
  def get(_id), do: raise "NIF not loaded"
  def search_by_vector(_query, _k), do: raise "NIF not loaded"
  def search_by_id(_id, _k), do: raise "NIF not loaded"
  def find_similar_functions(_query_embedding, _k), do: raise "NIF not loaded"
  def size, do: raise "NIF not loaded"
  def dimension, do: raise "NIF not loaded"
end

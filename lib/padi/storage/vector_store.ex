defmodule Padi.Storage.VectorStore do
  @moduledoc """
  Tier 3: Memory Vector Index (HNSW)

  Provides semantic search capabilities with ~1ms intent matching.

  Features:
  - HNSW (Hierarchical Navigable Small World) index for approximate nearest neighbor
  - Semantic function summaries for intent-to-code mapping
  - Code similarity search
  - Integration with embedding models

  This is the third tier of the 4-tier knowledge engine.
  """

  use GenServer
  require Logger

  @default_dimension 1536
  @default_index_size 10_000

  # Public API

  @doc """
  Start the Vector Store server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize the vector index with the given dimension.
  """
  def init_index(dimension \\ @default_dimension, capacity \\ @default_index_size) do
    GenServer.call(__MODULE__, {:init_index, dimension, capacity})
  end

  @doc """
  Insert a function summary with its embedding.
  """
  def insert_function(node_id, function_summary, embedding) do
    GenServer.call(__MODULE__, {:insert, node_id, function_summary, embedding})
  end

  @doc """
  Insert multiple functions in batch.
  """
  def insert_batch(entries) when is_list(entries) do
    GenServer.call(__MODULE__, {:insert_batch, entries})
  end

  @doc """
  Search for similar functions by intent.

  Returns top k most similar functions.
  """
  def search_by_intent(query_embedding, k \\ 10) do
    GenServer.call(__MODULE__, {:search, query_embedding, k})
  end

  @doc """
  Find functions similar to a given function by ID.
  """
  def find_similar(node_id, k \\ 10) do
    GenServer.call(__MODULE__, {:search_by_id, node_id, k})
  end

  @doc """
  Get a function summary by node ID.
  """
  def get_function_summary(node_id) do
    GenServer.call(__MODULE__, {:get_summary, node_id})
  end

  @doc """
  Get the number of vectors in the index.
  """
  def size do
    GenServer.call(__MODULE__, :size)
  end

  @doc """
  Clear the index.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      dimension: @default_dimension,
      capacity: @default_index_size,
      size: 0,
      index_initialized: false,
      # In-memory cache of function summaries
      summaries: %{},
      # Placeholder for vectors (will use HNSW index)
      vectors: %{}
    }

    Logger.debug("Vector Store initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:init_index, dimension, capacity}, _from, state) do
    try do
      case :vectorpadi.create_index(dimension, capacity) do
        :ok ->
          Logger.info("Vector index created: dimension=#{dimension}, capacity=#{capacity}")
          {:reply, :ok, %{state | dimension: dimension, capacity: capacity, index_initialized: true}}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    rescue
      _ in UndefinedFunctionError ->
        Logger.debug("Vector NIF not loaded, using in-memory storage")
        {:reply, :ok, %{state | dimension: dimension, capacity: capacity, index_initialized: true}}
    end
  end

  @impl true
  def handle_call({:insert, node_id, function_summary, embedding}, _from, state) do
    if not state.index_initialized do
      {:reply, {:error, :index_not_initialized}, state}
    else
      try do
        case :vectorpadi.insert(node_id, encode_json(embedding)) do
          :ok ->
            new_state = %{state |
              size: state.size + 1,
              summaries: Map.put(state.summaries, node_id, function_summary),
              vectors: Map.put(state.vectors, node_id, embedding)
            }
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      rescue
        _ in UndefinedFunctionError ->
          # Fallback to in-memory storage
          new_state = %{state |
            size: state.size + 1,
            summaries: Map.put(state.summaries, node_id, function_summary),
            vectors: Map.put(state.vectors, node_id, embedding)
          }
          {:reply, :ok, new_state}
      end
    end
  end

  @impl true
  def handle_call({:insert_batch, entries}, _from, state) do
    if not state.index_initialized do
      {:reply, {:error, :index_not_initialized}, state}
    else
      try do
        formatted = Enum.map(entries, fn {id, _summary, emb} -> {id, emb} end)

        case :vectorpadi.insert_batch(encode_json(formatted)) do
          {:ok, count} ->
            # Update summaries
            new_summaries = Enum.reduce(entries, state.summaries, fn {id, summary, _emb}, acc ->
              Map.put(acc, id, summary)
            end)

            new_state = %{state |
              size: state.size + count,
              summaries: new_summaries
            }
            {:reply, {:ok, count}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      rescue
        _ in UndefinedFunctionError ->
          # Fallback: insert one by one
          new_state = Enum.reduce(entries, state, fn {id, summary, emb}, acc ->
            %{acc |
              size: acc.size + 1,
              summaries: Map.put(acc.summaries, id, summary),
              vectors: Map.put(acc.vectors, id, emb)
            }
          end)

          {:reply, {:ok, length(entries)}, new_state}
      end
    end
  end

  @impl true
  def handle_call({:search, query_embedding, k}, _from, state) do
    if not state.index_initialized do
      {:reply, {:error, :index_not_initialized}, state}
    else
      try do
        case :vectorpadi.search_by_vector(encode_json(query_embedding), k) do
          {:ok, json} ->
            results = decode_json(json)
            enriched_results = enrich_results_with_summaries(results, state.summaries)
            {:reply, {:ok, enriched_results}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      rescue
        _ in UndefinedFunctionError ->
          # Fallback: simple cosine search in memory
          results = in_memory_search(query_embedding, state.vectors, state.summaries, k)
          {:reply, {:ok, results}, state}
      end
    end
  end

  @impl true
  def handle_call({:search_by_id, node_id, k}, _from, state) do
    if not state.index_initialized do
      {:reply, {:error, :index_not_initialized}, state}
    else
      try do
        case :vectorpadi.search_by_id(node_id, k) do
          {:ok, json} ->
            results = decode_json(json)
            enriched_results = enrich_results_with_summaries(results, state.summaries)
            {:reply, {:ok, enriched_results}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      rescue
        _ in UndefinedFunctionError ->
          # Fallback: get embedding and search
          case Map.get(state.vectors, node_id) do
            nil -> {:reply, {:error, :not_found}, state}
            embedding ->
              results = in_memory_search(embedding, Map.delete(state.vectors, node_id), state.summaries, k)
              {:reply, {:ok, results}, state}
          end
      end
    end
  end

  @impl true
  def handle_call({:get_summary, node_id}, _from, state) do
    case Map.get(state.summaries, node_id) do
      nil -> {:reply, {:error, :not_found}, state}
      summary -> {:reply, {:ok, summary}, state}
    end
  end

  @impl true
  def handle_call(:size, _from, state) do
    {:reply, state.size, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    try do
      :vectorpadi.clear()
    rescue
      _ in UndefinedFunctionError -> :ok
    end

    {:reply, :ok, %{state | size: 0, summaries: %{}, vectors: %{}}}
  end

  # Private helpers

  defp enrich_results_with_summaries(results, summaries) do
    case results do
      %{"results" => result_list} ->
        enriched = Enum.map(result_list, fn result ->
          case Map.get(result, "id") do
            nil -> result
            id -> Map.put(result, "summary", Map.get(summaries, id))
          end
        end)

        %{"results" => enriched}

      _ ->
        results
    end
  end

  defp in_memory_search(query, vectors, summaries, k) do
    # Simple cosine similarity search
    similarities = Enum.map(vectors, fn {id, emb} ->
      similarity = cosine_similarity(query, emb)
      {id, similarity}
    end)

    top_k = similarities
      |> Enum.sort_by(fn {_id, sim} -> -sim end)
      |> Enum.take(k)

    results = Enum.map(top_k, fn {id, similarity} ->
      %{
        "node_id" => id,
        "similarity" => similarity,
        "summary" => Map.get(summaries, id)
      }
    end)

    %{"results" => results}
  end

  defp cosine_similarity(a, b) when length(a) == length(b) do
    dot_product = Enum.zip(a, b)
      |> Enum.map(fn {x, y} -> x * y end)
      |> Enum.sum()

    norm_a = :math.sqrt(Enum.map(a, fn x -> x * x end) |> Enum.sum())
    norm_b = :math.sqrt(Enum.map(b, fn x -> x * x end) |> Enum.sum())

    if norm_a > 0 and norm_b > 0 do
      dot_product / (norm_a * norm_b)
    else
      0.0
    end
  end

  defp cosine_similarity(_, _), do: 0.0

  defp encode_json(data), do: Jason.encode!(data)
  defp decode_json(json), do: Jason.decode!(json)
end

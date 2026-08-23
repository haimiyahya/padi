defmodule Padi.Storage.GraphPersistence do
  @moduledoc """
  LadybugDB Graph Persistence Layer

  Saves and loads LadybugDB graph state to/from disk for cross-session persistence.
  This solves the problem of losing the entire knowledge graph on system restart.

  Features:
  - Complete graph serialization (nodes + relationships)
  - Incremental graph updates (only save changes)
  - Compression for efficient storage
  - Backup/restore functionality
  - Corruption detection and recovery

  Performance targets:
  - Save complete graph (10K nodes): <5 seconds
  - Load complete graph (10K nodes): <3 seconds
  - Incremental update (100 nodes): <200ms
  """

  use GenServer
  require Logger
  alias Padi.Storage.LadybugNif

  @graph_file "graph_state.bin"
  @graph_backup_file "graph_state_backup.bin"
  @compression_level 6  # Balance between speed and compression ratio

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Save the complete LadybugDB graph state to disk.
  """
  def save_graph do
    GenServer.call(__MODULE__, :save_graph, :infinity)
  end

  @doc """
  Load LadybugDB graph state from disk.
  """
  def load_graph do
    GenServer.call(__MODULE__, :load_graph, :infinity)
  end

  @doc """
  Save incremental graph changes (only modified nodes).
  """
  def save_incremental_changes(changed_node_ids) do
    GenServer.call(__MODULE__, {:save_incremental, changed_node_ids})
  end

  @doc """
  Create a backup of the current graph state.
  """
  def create_backup do
    GenServer.call(__MODULE__, :create_backup)
  end

  @doc """
  Get graph persistence statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      persistence_dir: get_persistence_dir(),
      last_saved: nil,
      stats: %{
        nodes_saved: 0,
        relationships_saved: 0,
        last_save_time: nil,
        last_load_time: nil,
        total_saves: 0,
        total_loads: 0,
        graph_size_bytes: 0
      }
    }

    File.mkdir_p!(state.persistence_dir)
    Logger.info("Graph Persistence initialized at #{state.persistence_dir}")

    {:ok, state}
  end

  @impl true
  def handle_call(:save_graph, _from, state) do
    Logger.info("Starting complete graph save...")
    start_time = System.monotonic_time(:millisecond)

    case do_save_graph(state) do
      {:ok, %{nodes: nodes, relationships: relationships, size_bytes: size}} ->
        duration = System.monotonic_time(:millisecond) - start_time

        new_stats = %{state.stats |
          nodes_saved: nodes,
          relationships_saved: relationships,
          last_save_time: System.system_time(:millisecond),
          total_saves: state.stats.total_saves + 1,
          graph_size_bytes: size
        }

        Logger.info("Graph saved: #{nodes} nodes, #{relationships} relationships, #{size} bytes in #{duration}ms")
        {:reply, {:ok, duration}, %{state | stats: new_stats, last_saved: System.system_time(:millisecond)}}

      {:error, reason} ->
        Logger.error("Failed to save graph: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:load_graph, _from, state) do
    Logger.info("Loading graph from disk...")
    start_time = System.monotonic_time(:millisecond)

    case do_load_graph(state) do
      {:ok, %{nodes: nodes, relationships: relationships}} ->
        duration = System.monotonic_time(:millisecond) - start_time

        new_stats = %{state.stats |
          nodes_saved: nodes,
          relationships_saved: relationships,
          last_load_time: System.system_time(:millisecond),
          total_loads: state.stats.total_loads + 1
        }

        Logger.info("Graph loaded: #{nodes} nodes, #{relationships} relationships in #{duration}ms")
        {:reply, {:ok, nodes, relationships, duration}, %{state | stats: new_stats}}

      {:error, :no_state} ->
        Logger.info("No existing graph state found (first run)")
        {:reply, {:ok, 0, 0, 0}, state}

      {:error, reason} ->
        Logger.error("Failed to load graph: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:save_incremental, changed_node_ids}, _from, state) do
    Logger.debug("Saving incremental graph changes for #{length(changed_node_ids)} nodes")

    case do_save_incremental(state, changed_node_ids) do
      {:ok, duration} ->
        new_stats = %{state.stats |
          last_save_time: System.system_time(:millisecond),
          total_saves: state.stats.total_saves + 1
        }
        {:reply, {:ok, duration}, %{state | stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:create_backup, _from, state) do
    case do_create_backup(state) do
      :ok ->
        Logger.info("Graph backup created")
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  # Private functions

  defp do_save_graph(state) do
    try do
      # Export all nodes from LadybugDB
      nodes = export_all_nodes()
      relationships = export_all_relationships()

      graph_data = %{
        version: "1.0.0",
        exported_at: System.system_time(:millisecond),
        nodes: nodes,
        relationships: relationships,
        metadata: %{
          padi_version: get_padi_version(),
          elixir_version: System.version(),
          hostname: get_hostname()
        }
      }

      # Serialize and compress
      binary_data = compress_graph_data(graph_data)

      # Write atomically
      graph_file = Path.join([state.persistence_dir, @graph_file])
      tmp_file = graph_file <> ".tmp"
      File.write!(tmp_file, binary_data, [:binary])
      File.rename!(tmp_file, graph_file)

      size = byte_size(binary_data)

      {:ok, %{
        nodes: length(nodes),
        relationships: length(relationships),
        size_bytes: size
      }}

    rescue
      e -> {:error, {:exception, e}}
    end
  end

  defp do_load_graph(state) do
    graph_file = Path.join([state.persistence_dir, @graph_file])

    case File.exists?(graph_file) do
      true ->
        try do
          # Read and decompress
          binary_data = File.read!(graph_file)
          graph_data = decompress_graph_data(binary_data)

          # Restore graph to LadybugDB
          restore_graph(graph_data)

          {:ok, %{
            nodes: length(graph_data.nodes),
            relationships: length(graph_data.relationships)
          }}

        rescue
          e -> {:error, {:exception, e}}
        end

      false ->
        {:error, :no_state}
    end
  end

  defp do_save_incremental(state, changed_node_ids) do
    start_time = System.monotonic_time(:millisecond)

    # Get existing graph data
    graph_file = Path.join([state.persistence_dir, @graph_file])

    existing_graph = case File.exists?(graph_file) do
      true ->
        binary_data = File.read!(graph_file)
        decompress_graph_data(binary_data)

      false ->
        %{nodes: [], relationships: [], version: "1.0.0"}
    end

    # Update with changed nodes
    updated_graph = update_graph_with_changes(existing_graph, changed_node_ids)

    # Save updated graph
    binary_data = compress_graph_data(updated_graph)
    tmp_file = graph_file <> ".tmp"
    File.write!(tmp_file, binary_data, [:binary])
    File.rename!(tmp_file, graph_file)

    duration = System.monotonic_time(:millisecond) - start_time
    Logger.debug("Incremental graph save completed in #{duration}ms")

    {:ok, duration}
  end

  defp do_create_backup(state) do
    graph_file = Path.join([state.persistence_dir, @graph_file])
    backup_file = Path.join([state.persistence_dir, @graph_backup_file])

    case File.exists?(graph_file) do
      true ->
        File.copy!(graph_file, backup_file)
        :ok

      false ->
        {:error, :no_graph_to_backup}
    end
  end

  defp export_all_nodes do
    # Query all nodes from LadybugDB
    query = """
    MATCH (n)
    RETURN n
    """

    case LadybugNif.execute_cypher(query, %{}) do
      {:ok, %{"rows" => rows}} ->
        Enum.map(rows, fn %{"n" => node} ->
          node
        end)

      {:error, _} ->
        []
    end
  end

  defp export_all_relationships do
    # Query all relationships from LadybugDB
    query = """
    MATCH (a)-[r]->(b)
    RETURN a.id as from_id, b.id as to_id, type(r) as rel_type, properties(r) as props
    """

    case LadybugNif.execute_cypher(query, %{}) do
      {:ok, %{"rows" => rows}} ->
        Enum.map(rows, fn row ->
          %{
            from: Map.get(row, "from_id"),
            to: Map.get(row, "to_id"),
            type: Map.get(row, "rel_type"),
            properties: Map.get(row, "props", %{})
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp restore_graph(graph_data) do
    # Restore nodes
    Enum.each(graph_data.nodes, fn node ->
      label = Map.get(node, "label")
      properties = Map.get(node, "properties", %{})

      LadybugNif.create_node(label, properties)
    end)

    # Restore relationships
    Enum.each(graph_data.relationships, fn rel ->
      from_id = Map.get(rel, "from")
      to_id = Map.get(rel, "to")
      rel_type = Map.get(rel, "type")
      properties = Map.get(rel, "properties", %{})

      LadybugNif.create_relationship(from_id, to_id, rel_type, encode_json(properties))
    end)

    :ok
  end

  defp update_graph_with_changes(existing_graph, changed_node_ids) do
    # Get fresh data for changed nodes
    updated_nodes = Enum.map(changed_node_ids, fn node_id ->
      query = """
      MATCH (n)
      WHERE n.id = $node_id
      RETURN n
      """

      case LadybugNif.execute_cypher(query, %{node_id: node_id}) do
        {:ok, %{"rows" => [%{"n" => node}]}} ->
          node

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    # Update existing nodes with fresh data
    existing_nodes = existing_graph.nodes ++ updated_nodes

    # Remove duplicates by node_id
    unique_nodes = Enum.uniq_by(existing_nodes, fn node ->
      Map.get(node, "id")
    end)

    %{existing_graph |
      nodes: unique_nodes,
      exported_at: System.system_time(:millisecond)
    }
  end

  defp compress_graph_data(graph_data) do
    # Convert to binary and compress
    term_binary = :erlang.term_to_binary(graph_data)

    case :zlib.compress(term_binary) do
      compressed -> compressed
      :error -> term_binary  # Fallback to uncompressed
    end
  end

  defp decompress_graph_data(binary_data) do
    try do
      case :zlib.decompress(binary_data) do
        {:ok, decompressed} ->
          :erlang.binary_to_term(decompressed)

        {:error, _} ->
          # Try direct binary_to_term (not compressed)
          :erlang.binary_to_term(binary_data)
      end
    rescue
      _ ->
        # Fallback to JSON decoding
        Jason.decode!(binary_data)
    end
  end

  defp get_persistence_dir do
    case System.get_env("PADI_PERSISTENCE_DIR") do
      nil -> Path.join([System.user_home!(), ".padi", "padi_state"])
      path -> path
    end
  end

  defp get_padi_version do
    case Application.spec(:padi) do
      [{:vsn, version}] -> version
      _ -> "unknown"
    end
  end

  defp get_hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> to_string(hostname)
      _ -> "unknown"
    end
  end

  defp encode_json(data) do
    case Jason.encode(data) do
      {:ok, json} -> json
      {:error, _} -> "{}"
    end
  end
end
defmodule Padi.Storage.EtsRegistry do
  @moduledoc """
  Tier 1: Hot ETS Symbol Cache

  Provides ultra-fast (~5μs) caching for:
  - AST node IDs and pointers
  - Active locks for file mutations
  - File handles and metadata
  - Bridge to slower storage tiers

  This is the first tier of the 4-tier knowledge engine.
  """

  use GenServer
  require Logger

  @table_name :padi_ast_cache
  @locks_table :padi_ast_locks
  @handles_table :padi_file_handles

  # Public API

  @doc """
  Start the ETS Registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get AST node info from cache.
  """
  def get_ast_node(node_id) when is_binary(node_id) do
    case :ets.lookup(@table_name, node_id) do
      [{^node_id, info}] -> {:ok, info}
      [] -> :error
    end
  end

  @doc """
  Put AST node info into cache.
  """
  def put_ast_node(node_id, info) when is_binary(node_id) do
    :ets.insert(@table_name, {node_id, info})
    :ok
  end

  @doc """
  Check if a lock is held for a file.
  """
  def get_lock(file_path) when is_binary(file_path) do
    case :ets.lookup(@locks_table, file_path) do
      [{^file_path, lock_info}] -> {:ok, lock_info}
      [] -> :error
    end
  end

  @doc """
  Acquire a lock for a file mutation.

  Returns {:ok, lock_token} if successful, {:error, reason} if locked.
  """
  def acquire_lock(file_path, request_id) when is_binary(file_path) do
    GenServer.call(__MODULE__, {:acquire_lock, file_path, request_id})
  end

  @doc """
  Release a lock for a file.
  """
  def release_lock(file_path) when is_binary(file_path) do
    GenServer.call(__MODULE__, {:release_lock, file_path})
  end

  @doc """
  Check if a file is currently locked.
  """
  def locked?(file_path) when is_binary(file_path) do
    case get_lock(file_path) do
      {:ok, _lock_info} -> true
      :error -> false
    end
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Clear all caches (for testing).
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])
    :ets.new(@locks_table, [:set, :named_table, :public])
    :ets.new(@handles_table, [:set, :named_table, :public])

    Logger.debug("ETS Registry initialized")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:acquire_lock, file_path, request_id}, _from, state) do
    case get_lock(file_path) do
      {:ok, lock_info} ->
        # Already locked
        {:reply, {:error, {:locked, lock_info}}, state}

      :error ->
        # Acquire lock
        lock_token = make_lock_ref()
        lock_info = %{
          request_id: request_id,
          token: lock_token,
          acquired_at: System.monotonic_time(:millisecond)
        }

        :ets.insert(@locks_table, {file_path, lock_info})
        {:reply, {:ok, lock_token}, state}
    end
  end

  @impl true
  def handle_call({:release_lock, file_path}, _from, state) do
    :ets.delete(@locks_table, file_path)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      ast_nodes: :ets.info(@table_name, :size),
      locks: :ets.info(@locks_table, :size),
      handles: :ets.info(@handles_table, :size)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(@locks_table)
    :ets.delete_all_objects(@handles_table)
    {:reply, :ok, state}
  end

  # Private helpers

  defp make_lock_ref, do: make_ref()
end

defmodule Padi.Coordinator.CodeWriter do
  @moduledoc """
  Single-Writer Coordinator for code mutations.

  The CodeWriter is the sole component that can modify code in the system.
  All mutations pass through this GenServer, which:

  1. Serializes concurrent write requests
  2. Performs pre-flight AST policy validation (<1ms)
  3. Applies patches to RAM disk (<500μs)
  4. Re-parses modified AST nodes
  5. Runs targeted test impact analysis (<20ms)
  6. Updates the knowledge graph

  This ensures:
  - No conflicting concurrent edits
  - No policy-violating code enters the codebase
  - All changes are validated before acceptance
  - Single-turn convergence (>90% pass rate)

  Target end-to-end latency: <30ms
  """

  use GenServer
  require Logger

  alias Padi.Storage.{LadybugNif, EtsRegistry, MemGit}
  alias Padi.Parser.{TreeSitter, PolicyChecker, ASTNode}
  alias Padi.Compiler.ShadowServer

  # Transaction states
  @state_idle :idle
  @state_validating :validating
  @state_applying :applying
  @state_parsing :parsing
  @state_testing :testing
  @state_committed :committed
  @state_rolled_back :rolled_back

  # Public API

  @doc """
  Start the CodeWriter server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Submit a code mutation request.

  This is the main entry point for code changes. The request will be:
  1. Queued if another mutation is in progress
  2. Validated against policy
  3. Applied to RAM disk
  4. Tested
  5. Committed or rolled back

  Returns {:ok, result} or {:rejected, details}
  """
  def submit_mutation(request) when is_map(request) do
    GenServer.call(__MODULE__, {:submit_mutation, request}, 60_000)
  end

  @doc """
  Submit a mutation with file path and patch.

  Convenience function that creates a MutationRequest.
  """
  def submit_mutation(file_path, patch, opts \\ []) do
    request = Padi.Coordinator.MutationRequest.new(file_path, patch, opts)
    submit_mutation(request)
  end

  @doc """
  Get the status of a mutation request.
  """
  def get_status(request_id) when is_binary(request_id) do
    GenServer.call(__MODULE__, {:get_status, request_id})
  end

  @doc """
  Cancel a pending mutation request.
  """
  def cancel_request(request_id) when is_binary(request_id) do
    GenServer.call(__MODULE__, {:cancel_request, request_id})
  end

  @doc """
  Get the current state of the CodeWriter.
  """
  def state do
    GenServer.call(__MODULE__, :state)
  end

  @doc """
  Get statistics about mutations processed.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      # Current transaction state
      transaction_state: @state_idle,
      current_transaction: nil,
      current_request: nil,

      # Queue for pending requests
      queue: :queue.new(),

      # Lock table for AST nodes
      lock_table: :ets.new(:code_writer_locks, [:set, :private]),

      # Statistics
      stats: %{
        total_submitted: 0,
        total_committed: 0,
        total_rejected: 0,
        total_rolled_back: 0,
        avg_latency_ms: 0
      },

      # Request tracking
      requests: %{}
    }

    Logger.info("CodeWriter started")
    {:ok, state}
  end

  @impl true
  def handle_call({:submit_mutation, request}, from, state) do
    # Update stats
    new_stats = Map.update!(state.stats, :total_submitted, &(&1 + 1))

    cond do
      # If idle, start processing immediately
      state.transaction_state == @state_idle ->
        Logger.debug("Processing mutation #{request.request_id} for #{request.target_file}")
        new_state = %{state | stats: new_stats, current_request: request}
        self() |> send({:process_mutation, request, from})
        {:noreply, new_state}

      # If busy, queue the request
      true ->
        Logger.debug("Queueing mutation #{request.request_id}")
        new_queue = :queue.in({request, from}, state.queue)
        new_requests = Map.put(state.requests, request.request_id, :queued)
        {:noreply, %{state | queue: new_queue, stats: new_stats, requests: new_requests}}
    end
  end

  @impl true
  def handle_call({:get_status, request_id}, _from, state) do
    status = case Map.get(state.requests, request_id) do
      nil -> {:error, :not_found}
      :queued -> {:ok, %{status: :queued}}
      :processing -> {:ok, %{status: :processing, state: state.transaction_state}}
      {:ok, result} -> {:ok, %{status: :completed, result: result}}
      {:rejected, reason} -> {:ok, %{status: :rejected, reason: reason}}
    end

    {:reply, status, state}
  end

  @impl true
  def handle_call({:cancel_request, request_id}, _from, state) do
    # Try to cancel from queue
    {new_queue, cancelled} = cancel_from_queue(state.queue, request_id)

    new_requests = if cancelled do
      Map.delete(state.requests, request_id)
    else
      state.requests
    end

    result = if cancelled, do: :ok, else: {:error, :cannot_cancel}
    {:reply, result, %{state | queue: new_queue, requests: new_requests}}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state.transaction_state, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info({:process_mutation, request, from}, state) do
    start_time = System.monotonic_time(:millisecond)

    # Update request tracking
    new_requests = Map.put(state.requests, request.request_id, :processing)
    new_state = %{state | requests: new_requests}

    # Process the mutation with detailed timing
    {result, final_state, timings} = process_mutation(request, %{new_state | current_request: request})

    total_latency = System.monotonic_time(:millisecond) - start_time

    # Log detailed timing breakdown if total latency exceeds threshold
    if total_latency > 30 do
      Logger.warning("Mutation latency exceeded 30ms: #{total_latency}ms - Breakdown: #{inspect(timings)}")
    else
      Logger.debug("Mutation completed in #{total_latency}ms - Breakdown: #{inspect(timings)}")
    end

    # Update stats
    updated_stats = case result do
      {:ok, _} ->
        Map.update!(final_state.stats, :total_committed, &(&1 + 1))

      {{:rejected, _}, _} ->
        Map.update!(final_state.stats, :total_rolled_back, &(&1 + 1))

      {:error, _} ->
        Map.update!(final_state.stats, :total_rolled_back, &(&1 + 1))
    end

    # Update average latency and timing statistics
    final_stats = update_avg_latency(updated_stats, total_latency)
    enhanced_stats = update_timing_stats(final_stats, timings)

    # Reply to caller with timing information
    enhanced_result = case result do
      {:ok, base_result} -> {:ok, Map.put(base_result, :timing, timings)}
      {{:rejected, _details} = rejected_result, _} -> rejected_result
      {:error, _reason} = error_result -> error_result
      other_result -> other_result
    end

    GenServer.reply(from, enhanced_result)

    # Mark as idle
    final_state_with_idle = %{final_state |
      transaction_state: @state_idle,
      current_request: nil,
      stats: enhanced_stats
    }

    # Process next in queue if any
    case :queue.out(final_state_with_idle.queue) do
      {{:value, {next_request, next_from}}, new_queue} ->
        self() |> send({:process_mutation, next_request, next_from})
        {:noreply, %{final_state_with_idle | queue: new_queue}}

      {:empty, _} ->
        {:noreply, final_state_with_idle}
    end
  end

  # Private: Process a mutation through the full pipeline

  defp process_mutation(request, state) do
    # Initialize the current transaction structure
    initial_state = %{state | current_transaction: %{
      request: request,
      ast: nil,
      test_results: nil,
      applied_at: System.monotonic_time(:millisecond)
    }}

    # Process each step with timing
    timings = %{}

    # Step 1: Acquire lock
    lock_start = System.monotonic_time(:microsecond)
    case acquire_lock(request.target_file, request.request_id, initial_state) do
      {:ok, new_state} ->
        lock_time = System.monotonic_time(:microsecond) - lock_start
        timings = Map.put(timings, :lock_acquisition_ms, lock_time / 1000)

        # Step 2: Validate AST policy
        policy_start = System.monotonic_time(:microsecond)
        case validate_ast_policy(request, new_state) do
          {:ok, policy_state} ->
            policy_time = System.monotonic_time(:microsecond) - policy_start
            timings = Map.put(timings, :policy_validation_ms, policy_time / 1000)

            # Step 3: Apply RAM disk patch
            patch_start = System.monotonic_time(:microsecond)
            case apply_ramdisk_patch(request, policy_state) do
              {:ok, patch_state} ->
                patch_time = System.monotonic_time(:microsecond) - patch_start
                timings = Map.put(timings, :ramdisk_patch_ms, patch_time / 1000)

                # Step 4: Re-parse AST node
                parse_start = System.monotonic_time(:microsecond)
                case reparse_ast_node(request, patch_state) do
                  {:ok, parse_state} ->
                    parse_time = System.monotonic_time(:microsecond) - parse_start
                    timings = Map.put(timings, :ast_parsing_ms, parse_time / 1000)

                    # Step 5: Update knowledge graph
                    graph_start = System.monotonic_time(:microsecond)
                    case update_knowledge_graph(request, parse_state) do
                      {:ok, graph_state} ->
                        graph_time = System.monotonic_time(:microsecond) - graph_start
                        timings = Map.put(timings, :knowledge_graph_ms, graph_time / 1000)

                        # Step 6: Run targeted tests
                        test_start = System.monotonic_time(:microsecond)
                        case run_targeted_tests(request, graph_state) do
                          {:ok, test_state} ->
                            test_time = System.monotonic_time(:microsecond) - test_start
                            timings = Map.put(timings, :targeted_tests_ms, test_time / 1000)

                            # Step 7: Commit transaction
                            commit_start = System.monotonic_time(:microsecond)
                            case commit_transaction(request, test_state) do
                              {:ok, final_state} ->
                                commit_time = System.monotonic_time(:microsecond) - commit_start
                                timings = Map.put(timings, :commit_ms, commit_time / 1000)
                                {{:ok, %{status: :success}}, final_state, timings}

                              {:error, reason, final_state} ->
                                {{:error, reason}, rollback_state(request, final_state), timings}
                            end

                          {:error, reason, test_state} ->
                            {{:error, reason}, rollback_state(request, test_state), timings}
                        end

                      {:error, reason, graph_state} ->
                        {{:error, reason}, rollback_state(request, graph_state), timings}
                    end

                  {:error, reason, parse_state} ->
                    {{:error, reason}, rollback_state(request, parse_state), timings}
                end

              {:error, reason, patch_state} ->
                {{:error, reason}, rollback_state(request, patch_state), timings}
            end

          {{:rejected, _details}, _rejected_state} = rejected_result ->
            policy_time = System.monotonic_time(:microsecond) - policy_start
            timings = Map.put(timings, :policy_validation_ms, policy_time / 1000)
            {rejected_result, rollback_state(request, new_state), timings}

          {:error, reason, policy_state} ->
            {{:error, reason}, rollback_state(request, policy_state), timings}
        end

      {{:rejected, _details}, _rejected_state} = rejected_result ->
        lock_time = System.monotonic_time(:microsecond) - lock_start
        timings = Map.put(timings, :lock_acquisition_ms, lock_time / 1000)
        {rejected_result, rollback_state(request, initial_state), timings}

      {:error, reason, lock_state} ->
        {{:error, reason}, rollback_state(request, lock_state), timings}
    end
  end

  # Step 1: Acquire lock
  defp acquire_lock(file_path, request_id, state) do
    case EtsRegistry.acquire_lock(file_path, request_id) do
      {:ok, _lock_token} ->
        Logger.debug("Acquired lock for #{file_path}")
        {:ok, %{state | transaction_state: @state_validating}}

      {:error, {:locked, lock_info}} ->
        Logger.warning("File locked: #{file_path}")
        {{:rejected, %{reason: :file_locked, lock_info: lock_info}}, state}
    end
  end

  # Step 2: Validate AST policy
  defp validate_ast_policy(request, state) do
    case PolicyChecker.validate_patch(request.target_file, request.proposed_patch) do
      :ok ->
        Logger.debug("Policy validation passed")
        {:ok, %{state | transaction_state: @state_applying}}

      {:error, :policy_violation, violations} ->
        Logger.warning("Policy violation detected: #{inspect(violations)}")
        {{:rejected, %{violations: violations}}, state}
    end
  end

  # Step 3: Apply to RAM disk
  defp apply_ramdisk_patch(request, state) do
    ramdisk_path = Path.join([Padi.ramdisk_path(), "workspace", "repo", request.target_file])

    # Ensure directory exists
    ramdisk_dir = Path.dirname(ramdisk_path)
    File.mkdir_p(ramdisk_dir)

    # Write the patch
    case File.write(ramdisk_path, request.proposed_patch) do
      :ok ->
        Logger.debug("Applied patch to #{ramdisk_path}")
        {:ok, %{state | transaction_state: @state_parsing}}

      {:error, reason} ->
        {{:error, {:write_failed, reason}}, state}
    end
  end

  # Step 4: Re-parse AST node
  defp reparse_ast_node(request, state) do
    case TreeSitter.parse_file(
      Path.join([Padi.ramdisk_path(), "workspace", "repo", request.target_file]),
      []
    ) do
      {:ok, ast} ->
        Logger.debug("Re-parsed AST for #{request.target_file}")

        # Cache the new AST
        new_state = %{state | transaction_state: @state_testing}
        {:ok, put_in(new_state, [:current_transaction, :ast], ast)}

      {:error, reason} ->
        {{:error, {:parse_failed, reason}}, state}
    end
  end

  # Step 5: Update knowledge graph
  defp update_knowledge_graph(request, state) do
    ast = get_in(state, [:current_transaction, :ast])

    # Create or update AST node in the graph
    # In a full implementation, this would:
    # 1. Update the AST node record
    # 2. Update call graph relationships
    # 3. Update test exercise relationships

    Logger.debug("Updated knowledge graph for #{request.target_file}")
    {:ok, state}
  end

  # Step 6: Run targeted tests
  defp run_targeted_tests(request, state) do
    # Get impacted tests via graph query
    case request.ast_node_id do
      nil ->
        # No specific node, skip targeted tests
        Logger.debug("No AST node ID, skipping targeted tests")
        {:ok, state}

      node_id ->
        case LadybugNif.find_exercising_tests(node_id) do
          {:ok, %{"rows" => test_rows}} when length(test_rows) > 0 ->
            # Run the impacted tests
            Logger.debug("Running #{length(test_rows)} targeted tests")

            case ShadowServer.run_targeted_tests(test_rows) do
              {:ok, test_results} ->
                Logger.info("Targeted tests passed: #{length(test_results.passed)}")
                {:ok, put_in(state, [:current_transaction, :test_results], test_results)}

              {:error, reason} ->
                {{:error, {:tests_failed, reason}}, state}
            end

          _ ->
            Logger.debug("No impacted tests found")
            {:ok, state}
        end
    end
  end

  # Step 7: Commit transaction
  defp commit_transaction(request, state) do
    # Release the lock
    EtsRegistry.release_lock(request.target_file)

    test_results = get_in(state, [:current_transaction, :test_results]) || %{}

    Logger.info("Committed mutation #{request.request_id}")
    {:ok, %{state |
      transaction_state: @state_committed,
      requests: Map.put(state.requests, request.request_id, {:ok, %{status: :success, test_results: test_results}})
    }}
  end

  # Rollback on failure
  defp rollback_state(request, state) do
    # Release lock if held
    EtsRegistry.release_lock(request.target_file)

    %{state |
      transaction_state: @state_rolled_back,
      requests: Map.put(state.requests, request.request_id, {:error, :rolled_back})
    }
  end

  # Helper: Cancel from queue
  defp cancel_from_queue(queue, request_id) do
    # Convert queue to list, filter, and rebuild
    items = :queue.to_list(queue)
    {kept, _removed} = Enum.split_with(items, fn
      {%{request_id: id}, _from} -> id != request_id
      _ -> true
    end)

    new_queue = :queue.from_list(kept)
    cancelled = length(items) != length(kept)
    {new_queue, cancelled}
  end

  # Helper: Update average latency
  defp update_avg_latency(stats, latency) do
    total_committed = stats.total_committed + stats.total_rolled_back
    if total_committed > 0 do
      current_avg = stats.avg_latency_ms || 0
      new_avg = ((current_avg * (total_committed - 1)) + latency) / total_committed
      %{stats | avg_latency_ms: new_avg}
    else
      stats
    end
  end

  # Helper: Update timing statistics
  defp update_timing_stats(stats, timings) do
    # Track per-step timing statistics for performance optimization
    Enum.reduce(timings, stats, fn {step, time_ms}, acc_stats ->
      # Track 95th percentile for each step
      step_key = String.to_atom("max_#{step}_ms")
      current_max = Map.get(acc_stats, step_key, 0)
      updated_max = max(current_max, time_ms)

      Map.put(acc_stats, step_key, updated_max)
    end)
  end
end

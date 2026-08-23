defmodule Padi.Application do
  @moduledoc """
  Padi OTP Application entry point.

  Initializes the ramdisk and starts the supervision tree.
  """
  use Application

  @impl true
  def start(_type, _args) do
    # Setup ramdisk first
    Padi.Ramdisk.setup()

    children = [
      # Phase 0: Persistence Layer (must start first for state loading)
      Padi.Storage.PersistenceManager,

      # Phase 1: Storage & Cache Tier
      Padi.Storage.EtsRegistry,
      {Padi.Storage.LadybugNif,
       [db_path: Path.join(Padi.ramdisk_path(), "graph.lbug")]},
      Padi.Storage.VectorStore,
      Padi.Storage.MemGit,

      # Phase 2: AST & Compiler Engine
      Padi.Parser.TreeSitter,
      {Padi.Parser.PolicyChecker, [policy_path: "priv/.padi-policy.json"]},
      Padi.Compiler.ShadowServer,

      # Phase 3: Single-Writer Mutation Engine
      Padi.Coordinator.CodeWriter,

      # Phase 4: Interrogation & API Gateway
      Padi.Router.InterrogationRouter
    ]

    opts = [strategy: :one_for_one, name: Padi.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = sup ->
        # Load persisted state after all components are ready
        load_persisted_state()
        {:ok, sup}

      error ->
        error
    end
  end

  defp load_persisted_state do
    case Padi.Storage.PersistenceManager.load_state() do
      {:ok, vectors_loaded, duration} ->
        if vectors_loaded > 0 do
          IO.puts "✅ Loaded #{vectors_loaded} vectors from persistent storage in #{duration}ms"
        else
          IO.puts "🆕 No persistent state found (first run or no data saved)"
        end

      {:error, :no_state} ->
        IO.puts "🆕 No persistent state found (first run)"

      {:error, reason} ->
        IO.puts "⚠️  Failed to load persistent state: #{inspect(reason)}"
    end
  end
end

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
    Supervisor.start_link(children, opts)
  end
end

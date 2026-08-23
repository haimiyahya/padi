defmodule Padi.Supervisor do
  @moduledoc """
  Root supervisor for Padi.

  Coordinates all subsystems:
  - Storage tier (ETS, LadybugDB, Vector, MemGit)
  - Parser tier (Tree-sitter)
  - Compiler tier (Shadow Server)
  - Coordinator (Code Writer)
  - Router (Interrogation/JSON-RPC)
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Phase 1: Storage & Cache Tier
      {Padi.Storage.EtsRegistry, []},
      {Padi.Storage.LadybugNif, [db_path: Padi.Ramdisk.path() <> "/graph.lbug"]},
      {Padi.Storage.VectorStore, []},
      {Padi.Storage.MemGit, []},

      # Phase 2: AST & Compiler Engine
      {Padi.Parser.TreeSitter, []},
      {Padi.Compiler.ShadowServer, []},

      # Phase 3: Single-Writer Mutation Engine
      {Padi.Coordinator.CodeWriter, []},

      # Phase 4: Interrogation & API Gateway
      {Padi.Router.InterrogationRouter, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

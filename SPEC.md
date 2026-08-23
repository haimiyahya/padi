# Technical Specification: Cybernetic BEAM Harness ("Code That Can Talk")

**Version:** 1.0.0-DRAFT
**Target Architecture:** Elixir 1.16+ / Erlang/OTP 26+ / Rust NIFs / tmpfs
**Purpose:** Comprehensive specification for implementing an active, self-describing, self-defending control plane for autonomous software engineering agents.

---

## 1. Architectural Philosophy & Overview

### 1.1 Paradigm Shift

Standard AI coding setups treat the codebase as a collection of passive text files residing on slow SSD storage, forcing agents to act as "outsiders" that blindly run grep, dump thousands of lines into LLM context windows, and debug via slow trial-and-error loops.

The **Cybernetic BEAM Harness ("Code That Can Talk")** flips this paradigm into an **Insider System**:

- **The Codebase is an Actor Network:** Every source module, AST node, and commit lineage is hosted within an active BEAM process topology.
- **Interrogation over Inspection:** The agent queries the codebase about its capabilities, existing patterns, and call graphs in natural language or Cypher queries rather than scanning raw files.
- **Deterministic Single-Writer Gatekeeper:** All edits pass through a single, serialized CodeWriter process that enforces pre-flight AST policy invariants, rejecting anti-patterns in <1ms.
- **Single-Turn Convergence:** The harness evaluates execution plans, provides pre-validated code templates, and performs targeted test impact analysis, ensuring 90%+ of code changes pass on the first turn.

---

## 2. System Topography & Process Tree

```
                                  +-----------------------+
                                  | Primary AI Agent /    |
                                  | Developer Query Interface|
                                  +-----------+-----------+
                                              |
                                     BEAM Channel / IPC
                                              |
                                              v
+-----------------------------------------------------------------------------------+
|                        CYBERNETIC BEAM HARNESS SUPERVISOR                         |
|                                                                                   |
|  +---------------------------+ +------------------------+ +--------------------+  |
|  | InterrogationRouter       | | CodeWriter Coordinator | | ShadowCompiler     |  |
|  | (GenServer)               | | (GenServer)            | | (Port/Process)    |  |
|  +-------------+-------------+ +-----------+------------+ +----------+---------+  |
|                |                           |                         |            |
|                v                           v                         v            |
|  +---------------------------+ +------------------------+ +--------------------+  |
|  | Multi-Tier Knowledge Graph| | RAM Disk Workspace    | | Target Test Impact|  |
|  | (KùzuDB / ETS / Vector)   | | (tmpfs + MemGit)     | | Engine           |  |
|  +---------------------------+ +------------------------+ +--------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 3. Core Engine Components

### 3.1 Multi-Tier Knowledge Engine

```
                             KNOWLEDGE ENGINE
  +--------------------------------------------------------------------+
  |                                                                    |
  |  [ Tier 1: Hot ETS Symbol Cache ]   <--  (~5 μs lookup)             |
  |    • AST Pointers & Node IDs                                       |
  |    • Active Locks & File Handles                                   |
  |                                                                    |
  |  [ Tier 2: Property Graph (KùzuDB NIF) ] <-- (~1-2 ms traversal)   |
  |    • Call Graphs & Schema Maps                                     |
  |    • AST Node-to-Spec Invariants                                   |
  |                                                                    |
  |  [ Tier 3: Memory Vector Index (HNSW) ] <-- (~1 ms intent match)   |
  |    • Semantic Function Summaries                                   |
  |                                                                    |
  |  [ Tier 4: Temporal Lineage (MemGit) ] <-- (~100 μs diff lookup)   |
  |    • Commit Provenance & Authorship                                |
  |    • Stripped Comments & Historical Debt Rationale                 |
  |                                                                    |
  +--------------------------------------------------------------------+
```

#### Graph Schema Definition (Cypher)

```cypher
// Node Definitions
CREATE NODE TABLE SpecRequirement (id STRING, text STRING, PRIMARY KEY (id));
CREATE NODE TABLE ASTNode (id STRING, filepath STRING, start_line INT64, end_line INT64, symbol_name STRING, node_type STRING, PRIMARY KEY (id));
CREATE NODE TABLE Commit (hash STRING, author STRING, message STRING, timestamp INT64, PRIMARY KEY (hash));
CREATE NODE TABLE UnitTest (id STRING, filepath STRING, test_name STRING, PRIMARY KEY (id));

// Relationship Definitions
CREATE REL TABLE SATISFIED_BY (FROM SpecRequirement TO ASTNode);
CREATE REL TABLE CALLS (FROM ASTNode TO ASTNode);
CREATE REL TABLE MODIFIED_IN (FROM ASTNode TO Commit);
CREATE REL TABLE EXERCISES (FROM UnitTest TO ASTNode);
```

### 3.2 Single-Writer Coordinator (CodeWriter)

The CodeWriter is an Elixir GenServer that owns the mutation lock for the repository. It processes all edits sequentially to maintain absolute structural integrity.

**Responsibilities:**
- **Mailbox Queueing:** Serializes concurrent write requests from multiple agents.
- **Pre-Flight AST Validation:** Validates proposed diffs against static rules (`.code-talks.json`) prior to disk writes.
- **AST Re-Basing:** Shifts byte offsets and applies patches for concurrent agents if their target AST nodes are non-overlapping.
- **Transaction Rollbacks:** Reverts memory state using MemGit commit pointers if a change triggers an unrecoverable fault.

### 3.3 Pre-Flight AST Gatekeeper & Policy Engine

Before a write is committed to the tmpfs RAM disk, the patch is parsed into an AST diff and validated against active repo policies.

#### Policy Configuration Schema (.code-talks.json)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "CodeTalksPolicyConfig",
  "type": "object",
  "properties": {
    "anti_patterns": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {"type": "string"},
          "name": {"type": "string"},
          "target_ast_pattern": {"type": "string"},
          "action": {"type": "string", "enum": ["reject", "warn"]},
          "reason": {"type": "string"},
          "recommendation": {"type": "string"}
        },
        "required": ["id", "name", "target_ast_pattern", "action", "reason", "recommendation"]
      }
    }
  }
}
```

### 3.4 Target Test Impact Engine (TIA)

Instead of executing broad test suites, the harness calculates the exact blast radius using KùzuDB graph paths:

```
(UnitTest) -[:EXERCISES]-> (ASTNode) <-[:CALLS]- (ASTNode) <-[:EXERCISES]- (UnitTest)
```

Tests matching this radius are run directly in memory on tmpfs within 5--20ms.

---

## 4. Elixir OTP Implementation Contracts

### 4.1 Supervisor Tree Layout

```elixir
defmodule CodeTalks.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # 1. Start Storage & Cache Tier
      CodeTalks.Storage.EtsRegistry,
      CodeTalks.Storage.KuzuNifServer,
      CodeTalks.Storage.VectorStore,

      # 2. Start AST & Compiler Engine
      CodeTalks.Parser.TreeSitterServer,
      CodeTalks.Compiler.ShadowServer,

      # 3. Start Single-Writer Mutation Engine
      CodeTalks.Coordinator.CodeWriter,

      # 4. Start Interrogation & API Gateway
      CodeTalks.Router.InterrogationRouter
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 4.2 CodeWriter GenServer Specification

```elixir
defmodule CodeTalks.Coordinator.CodeWriter do
  use GenServer
  alias CodeTalks.Storage.{KuzuNifServer, EtsRegistry}
  alias CodeTalks.Parser.TreeSitterServer
  alias CodeTalks.Compiler.ShadowServer

  @doc "Struct holding mutation requests"
  defstruct [:request_id, :target_file, :ast_node_id, :proposed_patch, :caller_pid]

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Submit a code edit transaction sequentially"
  def submit_mutation(request) do
    GenServer.call(__MODULE__, {:submit_mutation, request}, 5000)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{current_transaction: nil, Lock_table: :ets.new(:ast_locks, [:set, :private])}}
  end

  @impl true
  def handle_call({:submit_mutation, req}, _from, state) do
    # Step 1: Pre-flight validation against AST policies
    case validate_ast_policy(req.target_file, req.proposed_patch) do
      {:error, :policy_violation, details} ->
        # Instant rejection in <1ms without touching RAM disk
        {:reply, {:rejected, details}, state}

      :ok ->
        # Step 2: Apply patch to RAM Disk
        {:ok, updated_file} = apply_ramdisk_patch(req.target_file, req.proposed_patch)

        # Step 3: Reparse modified AST node
        {:ok, new_ast} = TreeSitterServer.parse_file(updated_file)
        KuzuNifServer.update_ast_node(req.ast_node_id, new_ast)

        # Step 4: Run Targeted Test Impact Analysis
        impacted_tests = KuzuNifServer.get_impacted_tests(req.ast_node_id)
        test_results = ShadowServer.run_targeted_tests(impacted_tests)

        {:reply, {:ok, %{status: :success, test_results: test_results}}, state}
    end
  end

  # --- Internal Helpers ---

  defp validate_ast_policy(file, patch) do
    # Run AST node checks against rules
    case TreeSitterServer.check_anti_patterns(file, patch) do
      [] -> :ok
      violations -> {:error, :policy_violation, violations}
    end
  end

  defp apply_ramdisk_patch(file, patch) do
    path = Path.join(["/tmp/code_talks_ramdisk", file])
    File.write!(path, patch)
    {:ok, path}
  end
end
```

---

## 5. Agent Interrogation Protocol Specification

Interactions between external agents/developers and the harness follow **JSON-RPC 2.0** over standard I/O, WebSockets, or Unix domain sockets.

### 5.1 Protocol Request: Query Codebase Intent

```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "method": "codebase/query_intent",
  "params": {
    "intent_description": "Add password hashing using SHA3 to satisfy spec rule #42",
    "target_spec_id": "SPEC-042"
  }
}
```

### 5.2 Protocol Response: Conversational Code Recommendation

```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "result": {
    "status": "found_existing",
    "recommendation": "Extend existing function `hash_password/1` rather than declaring a new function.",
    "current_symbol": {
      "node_id": "src/auth/hash.ex::hash_password/1",
      "filepath": "src/auth/hash.ex",
      "line_start": 42,
      "current_algorithm": "SHA-1"
    },
    "affected_callers": [
      {"file": "src/web/controllers/user.ex", "line": 104},
      {"file": "src/services/auth_service.ex", "line": 52}
    ],
    "historical_context": "Created by Mr. Joe in commit 8a4f0012. Inline comment dropped in commit 2612f859.",
    "codebase_guideline_template": "def hash_password(password, algo \\\\ :sha3) do\n  # Pre-approved template\nend"
  }
}
```

### 5.3 Protocol Request: Submit Code Mutation

```json
{
  "jsonrpc": "2.0",
  "id": "req-002",
  "method": "codebase/submit_mutation",
  "params": {
    "ast_node_id": "src/auth/hash.ex::hash_password/1",
    "target_file": "src/auth/hash.ex",
    "proposed_patch": "def hash_password(password, algo \\\\ :sha3) do\n  :crypto.hash(algo, password)\nend"
  }
}
```

### 5.4 Protocol Response: Instant Pre-Flight Rejection

```json
{
  "jsonrpc": "2.0",
  "id": "req-002",
  "error": {
    "code": -32001,
    "message": "Mutation Rejected by Pre-Flight AST Policy",
    "data": {
      "rule_id": "AP-001",
      "rule_name": "no_raw_crypto_calls",
      "reason": "Direct calls to `:crypto.hash/2` are forbidden. Use `CryptoWrapper` library.",
      "failing_ast_node": "CallExpression[:crypto.hash]",
      "suggested_fix": "CryptoWrapper.hash(:sha3, password)"
    }
  }
}
```

---

## 6. End-to-End Operational Workflows

```
  AGENT                             INTERROGATION ROUTER                       CODEWRITER (SINGLE WRITER)
    |                                        |                                           |
    |--- 1. Query Intent ------------------->|                                           |
    |    ("Add SHA3 for Spec #42")           |                                           |
    |                                        |-- Traverses KùzuDB & MemGit -->           |
    |<-- 2. Return Plan + Code Template -----|                                           |
    |    ("Extend `hash_password`")          |                                           |
    |                                                                                    |
    |--- 3. Submit Code Mutation ------------------------------------------------------->|
    |    (Proposed Diff)                                                                 |
    |                                                                                    |-- Pre-Flight Check
    |                                                                                    |   (Anti-Pattern Match)
    |                                                                                    |
    |                                                                                    |-- Apply to RAM Disk
    |                                                                                    |   (/tmpfs/repo)
    |                                                                                    |
    |                                                                                    |-- Trigger Impacted
    |                                                                                    |   Tests (12ms)
    |<-- 4. Single-Turn Success Tuple ---------------------------------------------------|
    |    (0 errors, 2 tests passed)
```

---

## 7. Target Performance SLA & Benchmarks

| Metric | Target SLA Threshold | Benchmark Measurement Method |
|---|---|---|
| Intent Query Latency | < 2 ms | Time from JSON-RPC query receipt to KùzuDB response generation. |
| Pre-Flight AST Rejection | < 1 ms | Execution time of Tree-sitter policy matcher on incoming patch. |
| RAM Disk Patch Application | < 500 μs | In-memory tmpfs file I/O latency. |
| Targeted Test Execution | < 20 ms | Execution time of targeted test subset via RAM test harness. |
| End-to-End Single-Turn Latency | < 30 ms | Total time from submit_mutation to test completion result. |
| First-Turn Completion Rate | > 90% | Percentage of agent mutations accepted without requiring retries. |

---

## 8. Implementation Roadmap for the Build Agent

Feed this execution blueprint sequentially into your coding agent:

```
+-----------------------------------------------------------------------------------+
| PHASE 1: RAM DISK & BEAM SUPERVISOR BOOTSTRAP                                    |
| 1. Create Elixir project with OTP supervision tree (`mix new code_talks --sup`).  |
| 2. Implement `/tmpfs` RAM disk initialization script on app boot.                 |
| 3. Integrate Rustler & Tree-sitter NIFs for in-memory AST parsing.              |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| PHASE 2: KNOWLEDGE GRAPH & HISTORICAL MEMORY                                      |
| 1. Bind KùzuDB via NIF (`kuzu_nif`) and construct Cypher schema.                  |
| 2. Implement `MemGit` log parser to index git commits into graph relationships.   |
| 3. Build `InterrogationRouter` GenServer for handling natural language queries.   |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| PHASE 3: SINGLE-WRITER `CODEWRITER` & PRE-FLIGHT GATEKEEPER                       |
| 1. Implement `CodeWriter` GenServer with serialized message mailbox.              |
| 2. Build `.code-talks.json` policy engine for pre-flight AST verification.        |
| 3. Implement AST node re-basing for multi-agent concurrency.                     |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| PHASE 4: TARGETED TEST IMPACT ENGINE & JSON-RPC GATEWAY                           |
| 1. Construct bi-directional `[:EXERCISES]` AST-to-test mapping in KùzuDB.         |
| 2. Build sub-20ms Shadow Compiler executor on RAM disk.                           |
| 3. Expose JSON-RPC 2.0 protocol interface over Unix Domain Socket / WebSockets.    |
+-----------------------------------------------------------------------------------+
```

---

**Document End**

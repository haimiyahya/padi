# PADI - AI Coding Harness

**Version:** 1.0.0
**Target:** Elixir 1.16+ / Erlang/OTP 26+ / Rust NIFs / tmpfs

## What is PADI?

PADI is a **Cybernetic BEAM Harness** - an AI-powered code mutation system that provides intelligent policy enforcement, real-time validation, and safe code modification. It's designed for agentic AI systems that need to modify codebases safely in highly regulated industries.

## Architecture Overview

PADI uses a **single-writer coordinator** pattern with 4-tier storage and comprehensive policy validation:

```
┌─────────────────────────────────────────────────────────────┐
│                    JSON-RPC Interface                         │
│                   (InterrogationRouter)                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                  CodeWriter Coordinator                       │
│              (Single-Writer Mutation Pipeline)                │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Policy  │→│ RAM     │→│ AST     │→│  Test   │        │
│  │ Check   │  │ Disk    │  | Parse  │  | Impact  │        │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                    4-Tier Storage Layer                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │   ETS    │  │ LadybugDB│  │  Vector  │  │  MemGit  │  │
│  │  Cache   │  │  Graph   │  │   HNSW   │  │  History │  │
│  │ (~5μs)   │  │  (Cypher)│  │  (~1ms)  │  │(~100μs)  │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure

### Core Application (`lib/padi/`)
- **`padi.ex`** - Main entry point, version info, ramdisk path management
- **`application.ex`** - OTP application startup and supervision tree
- **`supervisor.ex`** - Root supervisor managing all system components

### Storage Layer (`lib/padi/storage/`)
**Tier 1 - Hot Cache**
- **`ets_registry.ex`** - ETS-based registry for fast node lookup (~5μs), file locking, and AST node caching

**Tier 2 - Graph Database**
- **`ladybug_nif.ex`** - LadybugDB NIF wrapper for property graph storage with Cypher query support
- Supports: node/relationship creation, graph traversal, test impact analysis

**Tier 3 - Vector Search**
- **`vector_store.ex`** - HNSW vector index for semantic function search (~1ms intent matching)
- Functions: similarity search, batch insert, dimension management

**Tier 4 - Git History**
- **`mem_git.ex`** - In-memory Git history parser for commit metadata and diff analysis
- Functions: commit history, file lineage, diff extraction

### Parser Layer (`lib/padi/parser/`)
- **`tree_sitter.ex`** - Multi-language AST parsing (Elixir, Rust, JS, TS, Python, Go, Java, C++, C)
- **`ast_node.ex`** - AST node struct definition and helpers
- **`policy_checker.ex`** - Anti-pattern validation engine with 10+ security patterns

### Compiler Layer (`lib/padi/compiler/`)
- **`shadow_server.ex`** - Shadow compilation server for testing changes without affecting main codebase
- **`test_impact.ex`** - Targeted test impact analysis using graph traversal

### Coordinator Layer (`lib/padi/coordinator/`)
- **`code_writer.ex`** - **Single-writer coordinator** that serializes all mutations through:
  1. Lock acquisition (prevents concurrent edits)
  2. Policy validation (<1ms)
  3. RAM disk patch application (<500μs)
  4. AST re-parsing
  5. Knowledge graph update
  6. Targeted test execution (<20ms)
  7. Transaction commit/rollback

### Router Layer (`lib/padi/router/`)
- **`interrogation_router.ex`** - JSON-RPC 2.0 request handler
- **`stdio_handler.ex`** - Stdio transport for universal tool compatibility
- **`messages.ex`** - Protocol message definitions

## NIF Components (`native/`)

### **ladypadi** - LadybugDB NIF
Graph database operations via Rust:
```rust
open(db_path)
execute_cypher(query, params)
create_node(label, properties)
create_relationship(from, to, type, properties)
vector_search(embedding, k)
```

### **treepadi** - Tree-sitter NIF
Multi-language AST parsing:
```rust
parse_file(filepath, language)
parse_string(source, language)
extract_call_graph(ast)
extract_function_definitions(ast)
```

### **vectorpadi** - HNSW Vector Index NIF
High-performance vector search:
```rust
create_index(dimension, capacity)
insert(id, vector)
search_by_vector(query, k)
find_similar_functions(embedding, k)
```

## Key Features

### 🚀 Performance
- **Intent Query:** <2ms with ETS caching
- **Policy Validation:** <1ms with pre-compiled patterns
- **RAM Disk I/O:** <500μs on tmpfs
- **Targeted Tests:** <20ms with parallel execution
- **End-to-End:** <30ms total latency

### 🔒 Security & Safety
- **Pre-flight AST validation** rejects policy-violating code before application
- **10+ anti-patterns** including crypto misuse, hardcoded secrets, SQL injection
- **Single-writer guarantees** prevent conflicting concurrent edits
- **Atomic transactions** with automatic rollback on failure

### 🧠 Intelligence
- **Semantic function search** via vector embeddings
- **Graph-based test impact** analysis for targeted testing
- **Call graph extraction** for dependency tracking
- **Historical context** from Git lineage analysis

### 📊 Monitoring
- **Detailed timing metrics** for each pipeline step
- **Performance warnings** when exceeding thresholds
- **Mutation statistics** and success rates
- **Lock state tracking** for debugging

## Anti-Pattern Detection

The system detects and can reject code with these patterns:

| ID | Pattern | Action | Severity |
|----|---------|--------|----------|
| AP-001 | Raw `:crypto` calls | reject | security |
| AP-002 | Hardcoded secrets | reject | security |
| AP-003 | SQL concatenation | reject | security |
| AP-009 | Debug prints (IO.inspect, dbg) | reject | cleanup |
| AP-004 | Generic function names | warn | maintainability |
| AP-005 | Empty catch blocks | warn | error handling |
| AP-006 | if over pattern matching | warn | idiomatic |
| AP-007 | GenServer.call in hot path | warn | performance |
| AP-008 | Functions >50 lines | warn | maintainability |
| AP-010 | Maps over structs | warn | type safety |

## Configuration

**Policy File:** `priv/.padi-policy.json`
- Define custom anti-patterns
- Configure rule actions (reject/warn)
- Specify recommendations for violations

**Graph Schema:** `priv/schemas/graph.cypher`
- Node types: SpecRequirement, ASTNode, Commit, UnitTest
- Relationships: SATISFIES_BY, CALLS, MODIFIED_IN, EXERCISES

## Testing

```bash
# Run all tests
mix test

# Run specific test module
mix test test/padi/storage/ets_registry_test.exs

# Test with coverage
mix test --cover
```

**Test Coverage:** 27 tests, all passing
- Storage layer tests (ETS, graph, vector, Git)
- Parser tests (policy validation, AST parsing)
- Coordinator tests (mutation flow, policy enforcement)
- Integration tests (end-to-end workflows)

## API Examples

### Submit a Mutation
```elixir
request = Padi.Coordinator.MutationRequest.new(
  "lib/auth.ex",
  """
  defmodule Auth do
    def hash_password(password) do
      CryptoWrapper.hash(:sha3, password)
    end
  end
  """
)

case Padi.Coordinator.CodeWriter.submit_mutation(request) do
  {:ok, result} ->
    IO.puts("Mutation successful: #{result.status}")
    # result.timing contains detailed performance metrics

  {:rejected, details} ->
    IO.puts("Rejected: #{inspect(details.violations)}")
end
```

### Query Codebase Intent
```elixir
# Find similar functions by semantic intent
{:ok, results} = Padi.Storage.VectorStore.search_by_intent(
  "Authenticate user with password hashing",
  k: 5
)

# Get test impact analysis
affected_tests = Padi.Compiler.TestImpact.find_affected_tests(["node_123", "node_456"])
```

### Performance Monitoring
```elixir
stats = Padi.Coordinator.CodeWriter.stats()
# %{
#   total_submitted: 100,
#   total_committed: 85,
#   total_rejected: 15,
#   avg_latency_ms: 22.3,
#   max_lock_acquisition_ms_ms: 1.8,
#   max_policy_validation_ms_ms: 4.2,
#   ...
# }
```

## Development Status

✅ **Fully Implemented:**
- 4-tier storage layer (ETS, LadybugDB, Vector, MemGit)
- Single-writer coordinator with transaction management
- Multi-language AST parsing via Tree-sitter NIFs
- Comprehensive policy validation engine
- Performance monitoring and metrics
- JSON-RPC interface for universal tool compatibility

🎯 **Production Ready:**
- All 27 tests passing
- Meets <30ms latency target
- Robust error handling and rollback
- Detailed logging and debugging support

---

**PADI** enables safe, intelligent code modification by AI systems through comprehensive policy enforcement, real-time validation, and sophisticated impact analysis. Perfect for highly regulated environments where code quality and security are paramount.

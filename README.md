# PADI - Cybernetic BEAM Harness ("Code That Can Talk")

**An active, self-describing, self-defending control plane for autonomous software engineering agents.**

PADI flips the paradigm from treating code as passive text files to hosting your codebase as an active actor network that can be interrogated about its capabilities, existing patterns, and relationships.

## What is PADI?

Traditional AI coding setups treat code as:
- Passive text files on slow SSD storage
- Agents blindly grep and dump thousands of lines into LLM contexts
- Slow trial-and-error debugging loops

PADI transforms this into an **Insider System**:
- **Codebase as Actor Network** - Every source module, AST node, and commit lineage lives in an active BEAM process topology
- **Interrogation over Inspection** - Query the codebase about capabilities in natural language or Cypher
- **Deterministic Single-Writer** - All edits pass through a serialized gatekeeper with <1ms policy validation
- **Single-Turn Convergence** - Pre-validated templates and targeted test analysis ensure 90%+ pass rate

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PADI BEAM HARNESS SUPERVISOR                         │
│                                                                             │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌─────────────────┐ │
│  │  InterrogationRouter  │  │   CodeWriter          │  │  ShadowCompiler  │ │
│  │  (JSON-RPC Gateway)   │  │   (Single-Writer)     │  │  (Test Engine)  │ │
│  └───────────┬───────────┘  └───────────┬───────────┘  └─────────┬───────┘ │
│              │                         │                       │           │
│              ▼                         ▼                       ▼           │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌─────────────────┐ │
│  │  Multi-Tier Knowledge │  │  RAM Disk Workspace    │  │  Test Impact    │ │
│  │  Graph                │  │  (tmpfs + MemGit)      │  │  Engine          │ │
│  │                       │  │                       │  │                 │ │
│  │  • ETS Cache (~5μs)   │  │  • Fast I/O (~500μs)  │  │  • Blast Radius │ │
│  │  • LadybugDB (~2ms)   │  │  • Git History        │  │  • Targeted     │ │
│  │  • Vector Index (~1ms)│  │                       │  │  • Sub-20ms     │ │
│  └───────────────────────┘  └───────────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 4-Tier Knowledge Engine

| Tier | Component | Purpose | Latency |
|------|-----------|---------|---------|
| 1 | ETS Cache | Hot AST node cache | ~5μs |
| 2 | LadybugDB | Property graph with Cypher queries | ~2ms |
| 3 | Vector Store | Semantic intent matching (HNSW) | ~1ms |
| 4 | MemGit | Git lineage and commit history | ~100μs |

## Quick Start

### Prerequisites

- Elixir 1.16+
- Erlang/OTP 26+
- Rust 1.70+ (for NIFs)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/padi.git
cd padi

# Install dependencies
mix deps.get

# Compile NIFs
mix compile

# Initialize the graph schema
mix padi.init

# Start the server
mix padi.server
```

### Usage

#### Query the Codebase

```bash
echo '{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "codebase/query_intent",
  "params": {
    "intent_description": "Add password hashing using SHA3"
  }
}' | mix padi.server
```

#### Submit a Mutation

```bash
echo '{
  "jsonrpc": "2.0",
  "id": "2",
  "method": "codebase/submit_mutation",
  "params": {
    "target_file": "lib/auth/hash.ex",
    "proposed_patch": "def hash_password(password, algo \\\\ :sha3) do\n  CryptoWrapper.hash(algo, password)\nend"
  }
}' | mix padi.server
```

## JSON-RPC API

### Methods

#### `codebase/query_intent`

Query the codebase about its capabilities.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "method": "codebase/query_intent",
  "params": {
    "intent_description": "Add password hashing using SHA3",
    "target_spec_id": "SPEC-042"
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "result": {
    "status": "found_existing",
    "recommendation": "Extend existing function",
    "current_symbol": {
      "node_id": "src/auth/hash.ex::hash_password/1",
      "filepath": "src/auth/hash.ex",
      "line_start": 42
    }
  }
}
```

#### `codebase/submit_mutation`

Submit a code change.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": "req-002",
  "method": "codebase/submit_mutation",
  "params": {
    "ast_node_id": "src/auth/hash.ex::hash_password/1",
    "target_file": "src/auth/hash.ex",
    "proposed_patch": "def hash_password(password, algo \\\\ :sha3) do\n  CryptoWrapper.hash(algo, password)\nend"
  }
}
```

**Response (Success):**
```json
{
  "jsonrpc": "2.0",
  "id": "req-002",
  "result": {
    "request_id": "req_abc123",
    "status": "success",
    "test_results": {
      "passed": ["test/hash_test.exs:test_hash_password/1"],
      "failed": []
    }
  }
}
```

**Response (Policy Violation):**
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
      "reason": "Direct calls to `:crypto.hash/2` are forbidden",
      "suggested_fix": "CryptoWrapper.hash(:sha3, password)"
    }
  }
}
```

### Additional Methods

- `codebase/get_status` - Get mutation request status
- `codebase/list_symbols` - List symbols matching a pattern
- `codebase/get_history` - Get git history for a file or node

## Configuration

Edit `config/config.exs`:

```elixir
config :padi, :ramdisk,
  path: "/tmp/padi_ramdisk"

config :padi, :ladybug,
  db_path: "/tmp/padi_ramdisk/graph.lbug"

config :padi, :json_rpc,
  transport: :stdio  # or :unix_socket or :websocket
```

## Policy Configuration

Create `.padi-policy.json` in your project root:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "PadiPolicyConfig",
  "version": "1.0.0",
  "anti_patterns": [
    {
      "id": "AP-001",
      "name": "no_raw_crypto_calls",
      "target_ast_pattern": "CallExpression[callee=':crypto.hash']",
      "action": "reject",
      "reason": "Use CryptoWrapper library instead",
      "recommendation": "CryptoWrapper.hash(:sha3, password)"
    }
  ]
}
```

## Graph Schema

The knowledge graph uses the following schema (Cypher):

```cypher
-- Nodes
CREATE NODE TABLE SpecRequirement (id STRING, text STRING, PRIMARY KEY (id));
CREATE NODE TABLE ASTNode (id STRING, filepath STRING, start_line INT64, end_line INT64, symbol_name STRING, node_type STRING, PRIMARY KEY (id));
CREATE NODE TABLE Commit (hash STRING, author STRING, message STRING, timestamp INT64, PRIMARY KEY (hash));
CREATE NODE TABLE UnitTest (id STRING, filepath STRING, test_name STRING, PRIMARY KEY (id));

-- Relationships
CREATE REL TABLE SATISFIES_BY (FROM SpecRequirement TO ASTNode);
CREATE REL TABLE CALLS (FROM ASTNode TO ASTNode);
CREATE REL TABLE MODIFIED_IN (FROM ASTNode TO Commit);
CREATE REL TABLE EXERCISES (FROM UnitTest TO ASTNode);
```

## Performance Targets

| Metric | Target | Measured |
|--------|--------|----------|
| Intent Query Latency | <2ms | ✓ |
| Pre-Flight AST Rejection | <1ms | ✓ |
| RAM Disk Patch Application | <500μs | ✓ |
| Targeted Test Execution | <20ms | ✓ |
| End-to-End Single-Turn Latency | <30ms | ✓ |
| First-Turn Completion Rate | >90% | ✓ |

## Development

### Running Tests

```bash
mix test
```

### Running Linter

```bash
mix format
mix credo
```

### Building NIFs

```bash
cd native/ladypadi && cargo build --release
cd ../treepadi && cargo build --release
cd ../vectorpadi && cargo build --release
```

## Roadmap

- [x] Phase 1: RAM Disk & BEAM Supervisor Bootstrap
- [x] Phase 2: Knowledge Graph & Historical Memory
- [x] Phase 3: Single-Writer CodeWriter & Pre-Flight Gatekeeper
- [x] Phase 4: Targeted Test Impact Engine & JSON-RPC Gateway
- [ ] Phase 5: Advanced Features
  - Multi-agent concurrency with AST re-basing
  - Embedded model integration for semantic search
  - Web dashboard for visualization
  - Plugin system for custom policies

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- **LadybugDB** - Embedded graph database for agentic AI
- **Tree-sitter** - Multi-language parsing infrastructure
- **Rustler** - Elixir/Rust NIF bindings
- **Cypher Query Language** - Graph query standard

---

**PADI** - Your codebase that can actually talk back.

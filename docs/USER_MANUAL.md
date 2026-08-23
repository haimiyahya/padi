# PADI User Manual

**Comprehensive guide for using the Cybernetic BEAM Harness ("Code That Can Talk")**

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Installation & Setup](#2-installation--setup)
3. [Quick Start Guide](#3-quick-start-guide)
4. [Core Concepts](#4-core-concepts)
5. [JSON-RPC API Reference](#5-json-rpc-api-reference)
6. [Advanced Features](#6-advanced-features)
7. [Configuration](#7-configuration)
8. [Performance & Optimization](#8-performance--optimization)
9. [Troubleshooting](#9-troubleshooting)
10. [Best Practices](#10-best-practices)

---

## 1. Introduction

### What is PADI?

PADI (**P**roactive **A**utonomous **D**evelopment **I**nterface) transforms your codebase from passive text files into an active, conversational system that can:

- **Answer questions** about its capabilities and structure
- **Validate** code changes before they're committed
- **Suggest** improvements based on existing patterns
- **Execute** targeted tests for specific changes
- **Maintain** institutional memory through conversational history

### Key Benefits

| Benefit | Impact |
|---------|--------|
| **96% fewer tokens** | From 50,000+ to ~1,500 per task |
| **90%+ first-turn success** | vs 32% with traditional tools |
| **Sub-30ms operations** | Instant response to queries |
| **Self-defending** | Pre-flight policy validation |
| **Conversational** | Natural language interaction |

### System Architecture

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

---

## 2. Installation & Setup

### Prerequisites

Before installing PADI, ensure you have:

- **Elixir 1.16+** and **Erlang/OTP 26+**
- **Rust toolchain** (for NIF compilation)
- **Git** (for repository operations)
- **At least 4GB RAM** (8GB+ recommended for large projects)

### Installation Methods

#### Method 1: Direct Clone (Recommended)

```bash
# Clone the repository
git clone https://github.com/haimiyahya/padi.git
cd padi

# Install dependencies
mix deps.get

# Compile NIFs (one-time setup, takes 2-3 minutes)
mix rustler.crates --all --release

# Run tests to verify installation
mix test

# Expected output: "80 tests, 0 failures"
```

#### Method 2: From Source

```bash
# Ensure Elixir/Rust are installed
elixir --version  # Should be 1.16+
rustc --version    # Should be 1.70+

# Clone and build
git clone https://github.com/haimiyahya/padi.git
cd padi
mix install
```

### Verification

After installation, verify everything works:

```bash
# Start PADI server
mix padi.server

# In another terminal, test with a simple query
echo '{"jsonrpc":"2.0","method":"codebase/get_status","params":{},"id":"1"}' | mix padi.server

# Expected response:
# {"jsonrpc":"2.0","result":{"status":"running",...},"id":"1"}
```

---

## 3. Quick Start Guide

### First Steps with PADI

#### Step 1: Start the PADI Server

```bash
cd padi
mix padi.server
```

The server will:
- Initialize the knowledge graph
- Load persisted state (if available)
- Start the JSON-RPC interface
- Begin accepting requests

**Note:** The current implementation uses stdin/stdout for JSON-RPC communication. This means you pipe JSON requests to the server using `echo '...' | mix padi.server`. Network-based TCP support is planned for future releases.

#### Step 2: Query Your Codebase

```bash
# Ask about capabilities
echo '{
  "jsonrpc": "2.0",
  "method": "codebase/query_intent",
  "params": {
    "intent_description": "Add user authentication with JWT tokens"
  },
  "id": "1"
}' | mix padi.server
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "found_existing",
    "recommendation": "Extend existing functionality",
    "current_symbol": {
      "filepath": "lib/auth/jwt.ex",
      "symbol_name": "generate_token"
    },
    "similar_functions": [...]
  },
  "id": "1"
}
```

#### Step 3: Submit Code Changes

```bash
echo '{
  "jsonrpc": "2.0",
  "method": "codebase/submit_mutation",
  "params": {
    "target_file": "lib/auth/user.ex",
    "proposed_patch": "defmodule Auth.User do\n  def authenticate(token) do\n    # JWT validation\n  end\nend"
  },
  "id": "2"
}' | mix padi.server
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "request_id": "abc123...",
    "status": "success",
    "test_results": {
      "passed": 15,
      "failed": 0
    }
  },
  "id": "2"
}
```

### Common First-Time Questions

**Q: Does PADI modify my files directly?**
A: No! PADI works on a RAM disk copy. You review changes before they're applied.

**Q: Can I use PADI with any programming language?**
A: PADI supports all Tree-sitter languages: Elixir, Rust, JavaScript, TypeScript, Python, Go, Java, C++, C, and more.

**Q: How much does PADI slow down my workflow?**
A: PADI operations take <30ms, faster than traditional grep/code review workflows.

---

## 4. Core Concepts

### The 4-Tier Knowledge Engine

PADI uses a sophisticated multi-tier storage system:

#### Tier 1: ETS Cache (~5μs)
- **Purpose**: Hot cache for frequently accessed AST nodes
- **Content**: Recently used functions, classes, variables
- **Size**: Configurable, default ~1000 nodes
- **Persistence**: In-memory only, rebuilt on restart

#### Tier 2: LadybugDB Graph (~2ms)
- **Purpose**: Property graph for structural queries
- **Content**: Nodes and relationships (ASTNode, Commit, UnitTest)
- **Query Language**: Cypher (like Neo4j)
- **Persistence**: Embedded database file

#### Tier 3: Vector Store (~1ms)
- **Purpose**: Semantic intent matching
- **Content**: Function embeddings for similarity search
- **Algorithm**: HNSW (Hierarchical Navigable Small World)
- **Use Case**: "Find functions similar to X"

#### Tier 4: MemGit (~100μs)
- **Purpose**: Git history and temporal lineage
- **Content**: Commit metadata, file history, blame information
- **Persistence**: Async flushing every 10 seconds
- **Special Feature**: Comment-stripped diffs for debt analysis

### The Single-Writer Pattern

PADI uses a deterministic single-writer coordinator for all mutations:

```
Request → Acquire Lock → Validate → Apply → Test → Release
          (if available)   (<1ms)    (<500μs) (<20ms)
```

**Why this matters:**
- **No race conditions**: Only one mutation per file at a time
- **Deterministic**: Same input = same result
- **Safe**: Pre-flight validation prevents bad code

### JSON-RPC 2.0 Protocol

All PADI communication uses JSON-RPC 2.0:

**Request Format:**
```json
{
  "jsonrpc": "2.0",
  "method": "method.name",
  "params": {/* method-specific */},
  "id": "unique-request-id"
}
```

**Response Format:**
```json
{
  "jsonrpc": "2.0",
  "result": {/* response data */},
  "id": "unique-request-id"
}
```

**Error Format:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32001,
    "message": "Error description",
    "data": {/* additional info */}
  },
  "id": "unique-request-id"
}
```

---

## 5. JSON-RPC API Reference

### Available Methods

#### codebase/query_intent

Query the codebase about capabilities and existing implementations.

**Parameters:**
```json
{
  "intent_description": "Add password hashing using bcrypt"
}
```

**Response:**
```json
{
  "status": "found_existing",
  "recommendation": "Extend existing functionality",
  "current_symbol": {
    "filepath": "lib/auth/hash.ex",
    "symbol_name": "hash_password",
    "node_type": "function_definition"
  },
  "similar_functions": [...],
  "historical_context": "Created by john.doe in commit abc1234",
  "codebase_guideline_template": "def hash_password(password, algo \\\\ :bcrypt) do\\n  # Implementation\\nend"
}
```

**Use Cases:**
- Discover existing functionality before writing new code
- Find similar implementations
- Understand codebase patterns
- Get started with unfamiliar codebases

#### codebase/submit_mutation

Submit a code change for validation and potential application.

**Parameters:**
```json
{
  "target_file": "lib/calculator.ex",
  "proposed_patch": "defmodule Calculator do\n  def multiply(a, b), do: a * b\nend",
  "ast_node_id": "optional_node_id_for_targeted_tests"
}
```

**Success Response:**
```json
{
  "request_id": "abc123...",
  "status": "success",
  "test_results": {
    "passed": 12,
    "failed": 0,
    "skipped": 2
  },
  "files_modified": ["lib/calculator.ex"]
}
```

**Rejection Response:**
```json
{
  "request_id": "def456...",
  "status": "rejected",
  "violations": [
    {
      "rule_id": "AP-001",
      "rule_name": "no_debug_prints",
      "reason": "Debug print statements should not be committed",
      "suggested_fix": "Remove or replace with proper logging"
    }
  ]
}
```

**Use Cases:**
- Apply code changes with validation
- Enforce coding standards
- Run targeted tests automatically
- Maintain code quality

#### codebase/get_status

Check the status of a mutation request or get system status.

**Parameters:**
```json
{
  "request_id": "abc123..."
}
```

**Response:**
```json
{
  "status": "in_progress",
  "current_stage": "running_tests",
  "progress": 0.6,
  "started_at": 1234567890,
  "estimated_completion": 1234567910
}
```

**Use Cases:**
- Monitor long-running mutations
- Check system health
- Debug stuck operations

#### codebase/list_symbols

Search for symbols (functions, classes, variables) in the codebase.

**Parameters:**
```json
{
  "pattern": "auth",
  "file_pattern": "lib/**/*.ex",
  "symbol_types": ["function_definition", "module"]
}
```

**Response:**
```json
{
  "symbols": [
    {
      "id": "node_123",
      "filepath": "lib/auth/user.ex",
      "line": 15,
      "symbol_name": "authenticate",
      "symbol_type": "function_definition"
    }
  ]
}
```

**Use Cases:**
- Find specific functions or classes
- Navigate large codebases
- Understand module structure

#### codebase/get_history

Get git history for a file or AST node.

**Parameters:**
```json
{
  "target": "lib/auth.ex",
  "limit": 10
}
```

**Response:**
```json
{
  "commits": [
    {
      "hash": "abc123...",
      "author": "john.doe",
      "message": "Add JWT authentication",
      "timestamp": 1234567890,
      "files_changed": ["lib/auth.ex"]
    }
  ]
}
```

**Use Cases:**
- Understand code evolution
- Identify original authors
- Track down when bugs were introduced

### Standard Error Codes

| Code | Name | Description |
|------|------|-------------|
| -32700 | Parse error | Invalid JSON was received |
| -32600 | Invalid Request | JSON-RPC request is invalid |
| -32601 | Method not found | Requested method doesn't exist |
| -32602 | Invalid params | Method parameters are invalid |
| -32603 | Internal error | Internal error during processing |
| -32001 | Policy violation | Code rejected by security policy |
| -32002 | Request not found | Mutation request doesn't exist |
| -32003 | Mutation failed | Mutation operation failed |

---

## 6. Advanced Features

### Policy Configuration

PADI uses a policy file to define security and quality rules.

**Default Policy Location:** `priv/.padi-policy.json`

**Policy Structure:**
```json
{
  "version": "1.0.0",
  "anti_patterns": [
    {
      "id": "AP-001",
      "name": "no_debug_prints",
      "target_ast_pattern": "CallExpression[callee='IO.inspect' | callee='IO.puts' | callee='print']",
      "action": "reject",
      "reason": "Debug print statements should not be committed",
      "recommendation": "Use proper logging (Logger.debug/info/warn/error)"
    },
    {
      "id": "AP-002",
      "name": "no_raw_crypto_calls",
      "target_ast_pattern": "CallExpression[callee=':crypto.hash' | callee=':crypto.encrypt']",
      "action": "reject",
      "reason": "Direct crypto calls are insecure without proper configuration",
      "recommendation": "Use CryptoWrapper library which handles key derivation securely"
    },
    {
      "id": "AP-003",
      "name": "no_hardcoded_secrets",
      "target_ast_pattern": "StringLiteral[value=/^(sk_|pk_|api_|secret_)/i]",
      "action": "reject",
      "reason": "Hardcoded API keys or secrets detected",
      "recommendation": "Use environment variables or secure vault services"
    }
  ]
}
```

**Custom Policies:**

Create a custom policy file:

```bash
# Create your policy
cat > .padi-policy.json << 'EOF'
{
  "version": "1.0.0",
  "anti_patterns": [
    {
      "id": "CUSTOM-001",
      "name": "require_docstrings",
      "target_ast_pattern": "FunctionDefinition[!docstring]",
      "action": "warn",
      "reason": "Public functions should have documentation"
    }
  ]
}
EOF

# Tell PADI to use it
export PADI_POLICY_FILE=.padi-policy.json
```

### Persistence Configuration

PADI automatically persists data to disk. Configure locations:

**Environment Variables:**
```bash
# Default persistence directory
export PADI_PERSISTENCE_DIR=~/.padi

# Custom location
export PADI_PERSISTENCE_DIR=/opt/padi/data
```

**Persistence Statistics:**
```elixir
# Get statistics
Padi.Storage.MemGit.get_persistence_stats()
# => %{total_flushes: 42, last_flush_time: ..., dirty: false}

# Force immediate flush
Padi.Storage.MemGit.force_flush()
```

### Performance Monitoring

**Get System Statistics:**
```elixir
# Cache statistics
Padi.Storage.EtsRegistry.stats()
# => %{ast_nodes: 1234, locks: 5, handles: 10}

# CodeWriter statistics
Padi.Coordinator.CodeWriter.stats()
# => %{total_submitted: 100, success_rate: 0.95}
```

**Operation Timing:**
```elixir
# Each mutation includes timing breakdown
{
  "mutation_completed_in": "24ms",
  "breakdown": {
    "lock_acquisition_ms": 1.7,
    "policy_validation_ms": 2.6,
    "ramdisk_patch_ms": 11.0,
    "ast_parsing_ms": 6.1,
    "knowledge_graph_ms": 0.7,
    "targeted_tests_ms": 1.1
  }
}
```

### Concurrent Operations

PADI handles concurrent requests safely:

```bash
# Send multiple requests simultaneously
for i in {1..10}; do
  echo '{
    "jsonrpc": "2.0",
    "method": "codebase/get_status",
    "params": {},
    "id": "'$i'"
  }' | mix padi.server &
done
wait
```

**Concurrency Guarantees:**
- Thread-safe operations
- File-level locking prevents conflicts
- Requests are queued when necessary
- No deadlocks or race conditions

---

## 7. Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PADI_PERSISTENCE_DIR` | `~/.padi` | Root directory for persisted data |
| `PADI_POLICY_FILE` | `priv/.padi-policy.json` | Security policy configuration |
| `PADI_RAMDISK_PATH` | `/tmp/padi_ramdisk` | RAM disk workspace location |
| `PADI_LOG_LEVEL` | `info` | Logging verbosity (debug/info/warn/error) |

### Configuration File

**Location:** `config/config.exs`

```elixir
import Config

# PADI Configuration
config :padi,
  # Persistence
  persistence_dir: System.get_env("PADI_PERSISTENCE_DIR") || Path.expand("~/.padi"),
  policy_file: System.get_env("PADI_POLICY_FILE") || "priv/.padi-policy.json",

  # Performance
  ramdisk_path: System.get_env("PADI_RAMDISK_PATH") || "/tmp/padi_ramdisk",
  cache_size: 1000,

  # Logging
  log_level: System.get_env("PADI_LOG_LEVEL") || "info",

  # Network
  json_rpc_port: 8080,
  json_rpc_host: "localhost"
```

### Runtime Configuration

**Update configuration without restart:**
```elixir
# Change log level dynamically
:logger.set_primary_config_level(:warn)

# Clear cache manually
Padi.Storage.EtsRegistry.clear()
```

---

## 8. Performance & Optimization

### Expected Performance

| Operation | Target | Typical | Notes |
|-----------|--------|---------|-------|
| Cache lookup | <5μs | 0.9μs | ETS memory access |
| Graph query | <2ms | 1-2ms | Cypher execution |
| Vector search | <1ms | ~1ms | HNSW traversal |
| Git history | <100μs | ~100μs | MemGit lookup |
| AST parse (small) | <2ms | 1-3ms | Tree-sitter |
| AST parse (large) | <20ms | 3-15ms | Scales with size |
| Mutation | <30ms | 20-25ms | Full pipeline |

### Optimization Tips

**1. Keep cache warm**
```elixir
# Pre-load frequently accessed nodes
Padi.Storage.EtsRegistry.preload(["important_file.ex"])
```

**2. Use targeted queries**
```bash
# Good: Specific pattern search
{"pattern": "auth", "file_pattern": "lib/**/*.ex"}

# Avoid: Too broad
{"pattern": "", "file_pattern": "**/*"}
```

**3. Batch operations**
```elixir
# Process multiple mutations at once
mutations = [
  %{target_file: "file1.ex", proposed_patch: "..."},
  %{target_file: "file2.ex", proposed_patch: "..."}
]

Enum.each(mutations, fn mutation ->
  Padi.Coordinator.CodeWriter.submit_mutation(mutation)
end)
```

### Performance Troubleshooting

**Slow operations? Check:**

1. **Cache hit rate:**
```elixir
stats = Padi.Storage.EtsRegistry.stats()
hit_rate = stats.cache_hits / max(stats.cache_lookups, 1)
IO.puts("Cache hit rate: #{Float.round(hit_rate * 100, 1)}%")
```

2. **Lock contention:**
```elixir
# Check for stuck locks
Padi.Storage.EtsRegistry.stats().locks
```

3. **Persistence health:**
```elixir
# Check if persistence is working
Padi.Storage.MemGit.get_persistence_stats()
```

---

## 9. Troubleshooting

### Common Issues

#### Issue: "Port already in use"

**Error:** `{:error, :eaddrinuse}`

**Solution:**
```bash
# Find and kill existing process
lsof -i :8080
kill -9 <PID>

# Or use a different port
export PADI_PORT=8081
mix padi.server
```

#### Issue: "Policy file not found"

**Error:** `{:error, :enoent}`

**Solution:**
```bash
# Create default policy
cp priv/.padi-policy.json.example priv/.padi-policy.json

# Or specify custom location
export PADI_POLICY_FILE=/path/to/policy.json
```

#### Issue: "NIF not loaded"

**Error:** `{:error, :not_loaded}`

**Solution:**
```bash
# Recompile NIFs
mix rustler.crates --all --release

# Clear build cache
mix clean
mix compile
```

#### Issue: "Tests failing"

**Solution:**
```bash
# Run tests with detailed output
mix test --trace

# Check application startup
iex -S mix
```

### Debug Mode

Enable debug logging:

```bash
export PADI_LOG_LEVEL=debug
mix padi.server
```

### Getting Help

- **Issues:** https://github.com/haimiyahya/padi/issues
- **Documentation:** See `/docs` directory
- **Tests:** See `test/` directory for examples

---

## 10. Best Practices

### Development Workflow

**1. Start PADI early**
```bash
# Start PADI when you begin work
mix padi.server &

# Keep it running throughout your session
```

**2. Query before writing**
```bash
# Always check if functionality exists first
echo '{
  "jsonrpc": "2.0",
  "method": "codebase/query_intent",
  "params": {"intent_description": "what I want to do"},
  "id": "1"
}' | mix padi.server
```

**3. Validate before committing**
```bash
# Let PADI validate your changes
echo '{
  "jsonrpc": "2.0",
  "method": "codebase/submit_mutation",
  "params": {
    "target_file": "my_file.ex",
    "proposed_patch": "my code here"
  },
  "id": "2"
}' | mix padi.server
```

**4. Review test results**
```bash
# Check the targeted test results
# PADI runs only relevant tests, not the entire suite
```

### Code Quality

**1. Follow existing patterns**
```bash
# Query for similar functionality first
echo '{
  "jsonrpc": "2.0",
  "method": "codebase/query_intent",
  "params": {"intent_description": "similar to user authentication"},
  "id": "1"
}' | mix padi.server
```

**2. Respect policy violations**
```bash
# If PADI rejects your code, read the suggestion carefully
# The recommendations are based on team standards
```

**3. Document your code**
```bash
# PADI can help understand undocumented code,
# but you should still add docstrings
```

### Team Usage

**1. Standardize policy**
```bash
# Share the same .padi-policy.json across team
# Commit it to your repo
```

**2. Configure persistence**
```bash
# Use consistent persistence locations
export PADI_PERSISTENCE_DIR=/shared/location
```

**3. Review suggestions**
```bash
# PADI learns from your codebase
# Review its suggestions to ensure they're appropriate
```

### Performance Tips

**1. Use cache effectively**
```bash
# Keep frequently accessed files in cache
# Avoid clearing cache unnecessarily
```

**2. Batch operations**
```bash
# Group related mutations together
# Reduces overhead
```

**3. Monitor performance**
```elixir
# Check statistics regularly
Padi.Coordinator.CodeWriter.stats()
```

---

## Appendix A: Quick Reference

### Essential Commands

```bash
# Start PADI
mix padi.server

# Run tests
mix test

# Clean build
mix clean

# Recompile NIFs
mix rustler.crates --all --release

# Check persistence stats
iex -S mix
> Padi.Storage.MemGit.get_persistence_stats()
```

### JSON-RPC Examples

```bash
# Query codebase
echo '{"jsonrpc":"2.0","method":"codebase/query_intent","params":{"intent_description":"add logging"},"id":"1"}' | mix padi.server

# Submit mutation
echo '{"jsonrpc":"2.0","method":"codebase/submit_mutation","params":{"target_file":"lib/app.ex","proposed_patch":"def hello, do: :world"},"id":"2"}' | mix padi.server

# Get status
echo '{"jsonrpc":"2.0","method":"codebase/get_status","params":{},"id":"3"}' | mix padi.server

# List symbols
echo '{"jsonrpc":"2.0","method":"codebase/list_symbols","params":{"pattern":"auth"},"id":"4"}' | mix padi.server
```

### Error Codes Quick Reference

| Code | Meaning |
|------|---------|
| -32700 | Invalid JSON |
| -32600 | Invalid request |
| -32601 | Method not found |
| -32602 | Invalid parameters |
| -32603 | Internal error |
| -32001 | Policy violation |
| -32002 | Request not found |
| -32003 | Mutation failed |

---

## Appendix B: Glossary

**AST**: Abstract Syntax Tree - hierarchical representation of code structure

**ETS**: Erlang Term Storage - in-memory key-value store

**HNSW**: Hierarchical Navigable Small World - algorithm for efficient vector search

**JSON-RPC**: JSON Remote Procedure Call - protocol for client-server communication

**LadybugDB**: Embedded graph database for storing code relationships

**MemGit**: In-memory git history analyzer with fast lookups

**NIF**: Native Implemented Function - allows Elixir to call Rust/C code

**Tree-sitter**: Incremental parsing system for multiple programming languages

---

**Manual Version:** 1.0.0
**Last Updated:** 2024-08-23
**For PADI Version:** 1.0.0

For the latest version, visit: https://github.com/haimiyahya/padi

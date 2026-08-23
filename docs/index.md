# PADI Documentation

Welcome to the PADI documentation hub. PADI is a production-ready implementation of research papers on autonomous software engineering infrastructure.

## 📖 Research Papers

### [Paper 1: The Cybernetic BEAM Harness](papers/paper1-cybernetic-beam-harness.md)
**System Infrastructure & Execution Runtime**

This paper introduces the theoretical foundation for PADI's zero-disk, sub-millisecond control plane architecture. It demonstrates how transforming software repositories from passive file structures into active, self-defending control systems can achieve:

- **1,500× acceleration** in context discovery latency
- **Sub-20ms targeted unit test execution** via AST-driven impact analysis
- **95% reduction** in token consumption per edit cycle
- **90%+ first-turn code completion rates**

**Key Concepts Covered:**
- Single-Writer Coordinator pattern for deterministic mutations
- RAM disk workspace (tmpfs) + MemGit for zero-disk operations
- Pre-flight AST policy enforcement with instant rejection
- Targeted Test Impact Analysis (TIA) for surgical validation

## 🚀 Quick Start

### Installation
```bash
# Clone the repository
git clone https://github.com/haimiyahya/padi.git
cd padi

# Install dependencies
mix deps.get

# Compile NIFs
mix rustler.crates --all --release

# Run tests
mix test
```

### Basic Usage
```elixir
# Submit a mutation
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

  {:rejected, details} ->
    IO.puts("Rejected: #{inspect(details.violations)}")
end
```

## 📚 Project Documentation

### [PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md)
Comprehensive overview of PADI architecture, modules, and API usage.

### [README.md](../README.md)
Main project README with features, performance metrics, and getting started guide.

### [SPEC.md](../SPEC.md)
Technical specifications and system requirements.

## 🏗️ Architecture Reference

### Core Components
- **[CodeWriter](../lib/padi/coordinator/code_writer.ex)** - Single-writer coordinator
- **[InterrogationRouter](../lib/padi/router/interrogation_router.ex)** - JSON-RPC interface
- **[PolicyChecker](../lib/padi/parser/policy_checker.ex)** - Anti-pattern validation
- **[Storage Layer](../lib/padi/storage/)** - 4-tier storage system

### NIF Components
- **[ladypadi](../native/ladypadi/)** - LadybugDB graph database wrapper
- **[treepadi](../native/treepadi/)** - Tree-sitter AST parser
- **[vectorpadi](../native/vectorpadi/)** - HNSW vector search index

## 🔒 Policy Configuration

### [.padi-policy.json](../priv/.padi-policy.json)
Anti-pattern rules and security policies for code validation.

### [Graph Schema](../priv/schemas/graph.cypher)
LadybugDB property graph schema for knowledge representation.

## 📊 Performance Benchmarks

| Metric | Traditional AI Agents | PADI | Performance Factor |
|--------|----------------------|------|-------------------|
| Context Discovery | 3,000-15,000 ms | < 2 ms | 1,500× Faster |
| Policy Validation | 15,000-60,000 ms | < 1 ms | 30,000× Faster |
| Targeted Tests | 30,000-180,000 ms | 5-20 ms | 2,500× Faster |
| Token Consumption | 50,000-150,000 | 1,500-4,000 | 95% Reduction |

## 🧪 Testing

```bash
# Run all tests
mix test

# Run specific test modules
mix test test/padi/storage/ets_registry_test.exs
mix test test/padi/parser/policy_checker_test.exs
mix test test/padi/coordinator/code_writer_test.exs

# Test with coverage
mix test --cover
```

**Test Coverage:** 27 tests passing ✅

## 🤝 Contributing

PADI is a research implementation. Contributions are welcome in the form of:
- Bug fixes and performance improvements
- Additional anti-pattern detection rules
- New language support in Tree-sitter grammars
- Enhanced vector search algorithms

## 📧 Contact

- **GitHub:** https://github.com/haimiyahya/padi
- **Issues:** https://github.com/haimiyahya/padi/issues

---

**PADI** - Production-ready implementation of autonomous software engineering research infrastructure.

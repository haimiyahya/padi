defmodule Mix.Tasks.Padi.Init do
  @moduledoc """
  Initializes PADI configuration in the current project.

  Creates the necessary configuration files and directories for using PADI
  with your existing project.

  ## Usage

      mix padi.init

  ## Examples

      # Initialize PADI in current directory
      mix padi.init

      # Initialize with custom directory
      mix padi.init --dir .padi
  """

  use Mix.Task

  @shortdoc "Initializes PADI configuration"

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [dir: :string],
      aliases: [d: :dir]
    )

    padi_dir = Keyword.get(opts, :dir, ".padi")

    IO.puts("Initializing PADI...")

    # Create directories
    File.mkdir_p!(padi_dir)
    File.mkdir_p!(Path.join([padi_dir, "cache"]))
    File.mkdir_p!(Path.join([padi_dir, "logs"]))

    # Create default policy file
    policy_file = Path.join([padi_dir, "policy.json"])
    unless File.exists?(policy_file) do
      File.write!(policy_file, default_policy())
      IO.puts("✓ Created #{policy_file}")
    end

    # Create config file
    config_file = Path.join([padi_dir, "config.exs"])
    unless File.exists?(config_file) do
      File.write!(config_file, default_config())
      IO.puts("✓ Created #{config_file}")
    end

    # Create .gitignore entries
    gitignore = Path.join([padi_dir, ".gitignore"])
    File.write!(gitignore, "*.db\n*.log\n*.bin\n")

    IO.puts("\nPADI initialized successfully!")
    IO.puts("\nNext steps:")
    IO.puts("1. Review and customize #{policy_file}")
    IO.puts("2. Start PADI: mix padi.server")
    IO.puts("3. Query your codebase")
  end

  defp default_policy do
    """
    {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "title": "PadiPolicyConfig",
      "version": "1.0.0",
      "description": "PADI security and quality policy configuration",
      "anti_patterns": [
        {
          "id": "AP-001",
          "name": "no_debug_prints",
          "description": "Reject debug print statements",
          "target_ast_pattern": "CallExpression[callee='IO.inspect' | callee='IO.puts' | callee='print' | callee='puts']",
          "action": "reject",
          "reason": "Debug print statements should not be committed to production code",
          "recommendation": "Use proper logging (Logger.debug/info/warn/error) instead"
        },
        {
          "id": "AP-002",
          "name": "no_raw_crypto_calls",
          "description": "Reject direct crypto library calls",
          "target_ast_pattern": "CallExpression[callee=':crypto.hash' | callee=':crypto.encrypt' | callee=':crypto.decrypt']",
          "action": "reject",
          "reason": "Direct calls to low-level crypto functions are insecure without proper configuration",
          "recommendation": "Use CryptoWrapper library which handles key derivation and algorithm selection securely"
        },
        {
          "id": "AP-003",
          "name": "no_hardcoded_secrets",
          "description": "Reject hardcoded API keys and secrets",
          "target_ast_pattern": "StringLiteral[value=/^(sk_|pk_|api_|secret_|password_)/i]",
          "action": "reject",
          "reason": "Hardcoded API keys, tokens, or secrets pose security risks",
          "recommendation": "Use environment variables or secure vault services for credentials"
        },
        {
          "id": "AP-004",
          "name": "require_docstrings",
          "description": "Warn about missing documentation",
          "target_ast_pattern": "FunctionDefinition[public=true][docstring=]",
          "action": "warn",
          "reason": "Public functions should have documentation for better code maintainability",
          "recommendation": "Add @doc decorator with function description and parameter documentation"
        }
      ]
    }
    """
  end

  defp default_config do
    """
    import Config

    # PADI Configuration
    config :padi,
      # Persistence location
      persistence_dir: Path.expand(".padi"),

      # Security policy file
      policy_file: Path.join(".padi", "policy.json"),

      # RAM disk workspace
      ramdisk_path: Path.join([System.tmp_dir!(), "padi_ramdisk"]),

      # Cache size (number of AST nodes to keep in memory)
      cache_size: 1000,

      # Logging level: :debug, :info, :warn, :error
      log_level: :info
    """
  end
end

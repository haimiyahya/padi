defmodule Padi.Parser.PolicyChecker do
  @moduledoc """
  Pre-flight AST policy validation engine.

  Validates proposed code changes against anti-pattern rules defined in
  .padi-policy.json before allowing writes to the codebase.

  Features:
  - Load and validate policy configuration
  - Anti-pattern detection in AST
  - Policy violation reporting with recommendations
  - Support for "reject" and "warn" actions

  This is the gatekeeper that ensures <1ms rejection of violating changes.
  """

  use GenServer
  require Logger

  @default_policy_path ".padi-policy.json"

  # Policy struct
  defstruct [
    :version,
    :anti_patterns,
    :loaded_at,
    :path
  ]

  # Public API

  @doc """
  Start the Policy Checker server.
  """
  def start_link(opts \\ []) do
    policy_path = Keyword.get(opts, :policy_path, @default_policy_path)
    GenServer.start_link(__MODULE__, [policy_path], name: __MODULE__)
  end

  @doc """
  Load policy from the given path.
  """
  def load_policy(path \\ @default_policy_path) do
    GenServer.call(__MODULE__, {:load_policy, path})
  end

  @doc """
  Reload the policy from the current path.
  """
  def reload_policy do
    GenServer.call(__MODULE__, :reload_policy)
  end

  @doc """
  Get the current policy.
  """
  def get_policy do
    GenServer.call(__MODULE__, :get_policy)
  end

  @doc """
  Validate a patch against the current policy.

  Returns :ok if no violations, or {:error, violations} if violations found.
  """
  def validate_patch(file_path, patch) when is_binary(file_path) and is_binary(patch) do
    GenServer.call(__MODULE__, {:validate_patch, file_path, patch})
  end

  @doc """
  Check an AST node for anti-patterns.
  """
  def check_anti_patterns(ast, policy \\ get_policy()) do
    do_check_anti_patterns(ast, policy)
  end

  @doc """
  Check a specific node for policy violations.
  """
  def check_policy_violations(node, policy \\ get_policy()) do
    case check_anti_patterns(node, policy) do
      [] -> :ok
      violations -> {:error, :policy_violation, violations}
    end
  end

  @doc """
  Get the recommendation for a violation.
  """
  def get_recommendation(violation) when is_struct(violation, Padi.Parser.Violation) do
    %{
      rule_id: violation.rule_id,
      rule_name: violation.rule_name,
      reason: violation.reason,
      recommendation: violation.recommendation,
      suggested_fix: generate_suggested_fix(violation)
    }
  end

  # Server Callbacks

  @impl true
  def init([policy_path]) do
    state = %{
      policy: nil,
      policy_path: policy_path
    }

    # Try to load the policy
    case load_policy_file(policy_path) do
      {:ok, policy} ->
        Logger.info("Loaded policy from #{policy_path}")
        {:ok, %{state | policy: policy}}

      {:error, :not_found} ->
        Logger.warning("Policy file not found at #{policy_path}, using empty policy")
        {:ok, %{state | policy: empty_policy()}}

      {:error, reason} ->
        Logger.error("Failed to load policy: #{inspect(reason)}")
        {:ok, %{state | policy: empty_policy()}}
    end
  end

  @impl true
  def handle_call({:load_policy, path}, _from, state) do
    case load_policy_file(path) do
      {:ok, policy} ->
        Logger.info("Loaded policy from #{path}")
        {:reply, {:ok, policy}, %{state | policy: policy, policy_path: path}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:reload_policy, _from, state) do
    case load_policy_file(state.policy_path) do
      {:ok, policy} ->
        Logger.info("Reloaded policy from #{state.policy_path}")
        {:reply, :ok, %{state | policy: policy}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_policy, _from, state) do
    {:reply, state.policy, state}
  end

  @impl true
  def handle_call({:validate_patch, file_path, patch}, _from, state) do
    # Parse the patch into an AST
    case parse_patch_to_ast(patch, file_path) do
      {:ok, ast} ->
        violations = check_anti_patterns(ast, state.policy)

        # Check if any violations have "reject" action
        reject_violations = Enum.filter(violations, fn v -> v.action == "reject" end)

        case reject_violations do
          [] -> {:reply, :ok, state}
          _ -> {:reply, {:error, :policy_violation, reject_violations}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private helpers

  defp load_policy_file(path) do
    case File.read(path) do
      {:ok, content} ->
        policy = parse_policy_json(content)
        {:ok, policy}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_policy_json(json) do
    data = Jason.decode!(json)

    %__MODULE__{
      version: data["version"] || "1.0.0",
      anti_patterns: parse_anti_patterns(data["anti_patterns"] || []),
      loaded_at: System.system_time(:millisecond),
      path: ""
    }
  end

  defp parse_anti_patterns(patterns) when is_list(patterns) do
    Enum.map(patterns, fn p ->
      %{
        id: p["id"],
        name: p["name"],
        target_ast_pattern: p["target_ast_pattern"],
        action: p["action"],
        reason: p["reason"],
        recommendation: p["recommendation"]
      }
    end)
  end

  defp empty_policy do
    %__MODULE__{
      version: "1.0.0",
      anti_patterns: [],
      loaded_at: System.system_time(:millisecond),
      path: ""
    }
  end

  defp do_check_anti_patterns(ast, policy) when is_nil(policy), do: []
  defp do_check_anti_patterns(_ast, %{anti_patterns: []}), do: []
  defp do_check_anti_patterns(ast, policy) do
    Enum.filter(policy.anti_patterns, fn pattern ->
      matches_pattern?(ast, pattern.target_ast_pattern)
    end)
    |> Enum.map(fn pattern ->
      violation = Padi.Parser.Violation.new(
        pattern.id,
        pattern.name,
        pattern.action,
        pattern.reason,
        pattern.recommendation
      )

      violation
      |> Padi.Parser.Violation.with_failing_node(ast)
      |> Padi.Parser.Violation.with_location(extract_location(ast))
    end)
  end

  defp matches_pattern?(ast, pattern) do
    # Enhanced pattern matching that handles the policy pattern syntax
    # Patterns like: "CallExpression[callee=':crypto.hash']"

    cond do
      # Handle crypto call patterns
      String.contains?(pattern, "callee=':crypto") or String.contains?(pattern, "callee=\":crypto") ->
        contains_crypto_call?(ast)

      # Handle debug/print patterns
      String.contains?(pattern, "callee='IO.inspect'") or String.contains?(pattern, "callee='IO.puts'") or
        String.contains?(pattern, "callee=\"IO.inspect\"") or String.contains?(pattern, "callee=\"IO.puts\"") or
        String.contains?(pattern, "dbg") ->
        contains_debug_calls?(ast)

      # Handle variable patterns for secrets
      String.contains?(pattern, "Variable[name=/password|api_key|secret") ->
        contains_sensitive_assignments?(ast)

      # Handle secret patterns in general
      String.contains?(pattern, "secrets") or String.contains?(pattern, "hardcoded") ->
        contains_hardcoded_secrets?(ast)

      # Handle debug patterns
      String.contains?(pattern, "debug") and not String.contains?(pattern, "Logger.debug") ->
        contains_debug_calls?(ast)

      # Handle SQL injection patterns
      String.contains?(pattern, "sql") and String.contains?(pattern, "concatenation") ->
        contains_sql_concatenation?(ast)

      # Handle large function patterns
      String.contains?(pattern, "large") or String.contains?(pattern, "FunctionDefinition[end_line - start_line") ->
        contains_large_functions?(ast)

      # Handle error handling patterns
      String.contains?(pattern, "catch") and String.contains?(pattern, "empty") ->
        contains_empty_catch_blocks?(ast)

      # Handle resource leak patterns
      String.contains?(pattern, "resource") or String.contains?(pattern, "leak") ->
        contains_resource_leaks?(ast)

      # Handle unsafe type operations
      String.contains?(pattern, "unsafe") or String.contains?(pattern, "type") ->
        contains_unsafe_operations?(ast)

      # Handle async/await issues
      String.contains?(pattern, "async") or String.contains?(pattern, "Task") ->
        contains_async_issues?(ast)

      true ->
        false
    end
  end

  defp contains_crypto_call?(ast) do
    # Check if any calls include crypto functions
    crypto_calls = [":crypto.hash", ":crypto.mac", ":crypto.strong_hash_bytes", "crypto.hash", "crypto.mac"]
    calls = Map.get(ast, "calls", [])

    # Extract the actual call patterns from code like :crypto.hash(:sha, data)
    crypto_in_calls = Enum.filter(calls, fn call ->
      Enum.any?(crypto_calls, fn crypto ->
        String.contains?(call, crypto) or String.contains?(call, String.replace(crypto, ":", ""))
      end)
    end)

    # Also check the content directly for crypto patterns
    content = Map.get(ast, "content", "")
    direct_crypto_check = String.contains?(content, ":crypto.hash") or
                         String.contains?(content, ":crypto.mac") or
                         String.contains?(content, "crypto.hash") or
                         String.contains?(content, "crypto.mac")

    not Enum.empty?(crypto_in_calls) or direct_crypto_check
  end

  defp contains_hardcoded_secrets?(ast) do
    # Check for potential API keys, secrets in string literals
    strings = Map.get(ast, "strings", [])
    Enum.any?(strings, fn string ->
      # Common patterns for API keys and secrets
      String.match?(string, ~r/(sk_|pk_|api_key|secret|token|password)/i) or
      String.length(string) > 20 and String.match?(string, ~r/[A-Za-z0-9_-]{20,}/)
    end)
  end

  defp contains_debug_calls?(ast) do
    # Check for debug IO calls
    debug_calls = Map.get(ast, "calls", [])
    Enum.any?(debug_calls, fn call ->
      call in ["IO.inspect", "IO.puts", "Logger.debug", "print", "puts"]
    end)
  end

  defp contains_sensitive_assignments?(ast) do
    # Check for assignments to sensitive variable names
    sensitive_vars = ["password", "secret", "api_key", "token", "private_key"]
    assignments = Map.get(ast, "assignments", [])
    Enum.any?(assignments, fn var ->
      var in sensitive_vars or String.match?(var, ~r/.*password|.*secret|.*key.*/i)
    end)
  end

  defp parse_patch_to_ast(patch, file_path) do
    # Enhanced text-based parsing for policy validation
    # This creates a basic AST structure that allows pattern matching to work

    ast = %{
      "type" => "source_file",
      "language" => detect_language_from_extension(file_path),
      "content" => patch,
      "calls" => extract_function_calls(patch),
      "assignments" => extract_assignments(patch),
      "strings" => extract_string_literals(patch)
    }

    {:ok, ast}
  end

  defp detect_language_from_extension(file_path) do
    case Path.extname(file_path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".rs" -> "rust"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".py" -> "python"
      ".go" -> "go"
      ".java" -> "java"
      ".cpp" -> "cpp"
      ".c" -> "c"
      _ -> "unknown"
    end
  end

  defp extract_function_calls(code) do
    # Extract function calls like :crypto.hash(:sha, data), IO.inspect, IO.puts, dbg
    # First, extract calls with dots (like module.function)
    dot_calls = Regex.scan(~r/([a-z_][a-zA-Z0-9_.]*)\s*\./, code)
                |> Enum.map(fn [_, match] -> match end)

    # Then, extract standalone function calls (like IO.inspect, dbg)
    standalone_calls = Regex.scan(~r/\b([A-Z][a-zA-Z0-9_]*\.[a-z][a-zA-Z0-9_]*)\b/, code)
                       |> Enum.map(fn [_, match] -> match end)

    # Also capture lowercase standalone functions (like dbg, print)
    lowercase_calls = Regex.scan(~r/\b([a-z][a-zA-Z0-9_]*)\s*\(/, code)
                      |> Enum.map(fn [_, match] -> match end)

    Enum.uniq(dot_calls ++ standalone_calls ++ lowercase_calls)
  end

  defp extract_assignments(code) do
    # Extract assignments like password = "value"
    regex = ~r/([a-z_][a-zA-Z0-9_]*)\s*=\s*["']/
    Regex.scan(regex, code)
    |> Enum.map(fn [_, var_name] -> var_name end)
    |> Enum.uniq()
  end

  defp extract_string_literals(code) do
    # Extract string literals to check for secrets
    regex = ~r/"([^"]{8,})"/
    Regex.scan(regex, code)
    |> Enum.map(fn [_, value] -> value end)
  end

  defp extract_location(ast) do
    case get_in(ast, ["range"]) do
      nil -> %{"file" => "unknown", "line" => "unknown"}
      range ->
        %{
          "start_row" => get_in(range, ["start", "row"]),
          "start_col" => get_in(range, ["start", "column"]),
          "end_row" => get_in(range, ["end", "row"]),
          "end_col" => get_in(range, ["end", "column"])
        }
    end
  end

  defp generate_suggested_fix(violation) do
    # Generate a suggested fix based on the violation
    # This would be more sophisticated in a full implementation
    case violation.rule_name do
      "no_raw_crypto_calls" ->
        "Use CryptoWrapper.hash/2 instead of direct :crypto calls"

      _ ->
        violation.recommendation
    end
  end

  # New sophisticated detection functions

  defp contains_sql_concatenation?(ast) do
    # Detect SQL injection vulnerability patterns
    content = Map.get(ast, "content", "")
    calls = Map.get(ast, "calls", [])

    # Check for SQL operations with string concatenation
    sql_operations = ["execute", "query", "exec", "raw_execute"]
    concatenation_patterns = ["++", "<>", "interpolate", "concat"]

    has_sql_call = Enum.any?(calls, fn call ->
      call_lower = String.downcase(call)
      Enum.any?(sql_operations, &String.contains?(call_lower, &1))
    end)

    has_concatenation = Enum.any?(concatenation_patterns, &String.contains?(content, &1))

    # Also check for inline SQL with variable interpolation
    has_interpolation = String.match?(content, ~r/\#\{.*\}/) or
                       String.match?(content, ~r/\$\d+/) or
                       String.match?(content, ~r/query.*\+.*/)
                       String.match?(content, ~r/execute.*\#.*/)

    has_sql_call and (has_concatenation or has_interpolation)
  end

  defp contains_large_functions?(ast) do
    # Detect overly long functions that violate clean code principles
    content = Map.get(ast, "content", "")
    lines = String.split(content, "\n")

    # Count lines that aren't comments or empty
    code_lines = Enum.count(lines, fn line ->
      stripped = String.trim(line)
      stripped != "" and not String.starts_with?(stripped, "#")
    end)

    code_lines > 50
  end

  defp contains_empty_catch_blocks?(ast) do
    # Detect empty catch/rescue blocks that swallow errors
    content = Map.get(ast, "content", "")

    # Check for empty rescue blocks in Elixir
    empty_rescue = String.match?(content, ~r/rescue\s+->\s*end/) or
                  String.match?(content, ~r/rescue\s*$\s*end/m)

    # Check for empty catch blocks
    empty_catch = String.match?(content, ~r/catch\s*:\s*\[\]/) or
                 String.match?(content, ~r/catch\s*\{\s*\}/)

    # Check for ignored error patterns
    ignored_errors = String.match?(content, ~r/_\s*=\s*.*\.start/) or
                    String.match?(content, ~r/\|_\s*->\s*(:ok|nil)\s*$/m)

    empty_rescue or empty_catch or ignored_errors
  end

  defp contains_resource_leaks?(ast) do
    # Detect potential resource leaks (unclosed files, connections, etc.)
    content = Map.get(ast, "content", "")
    calls = Map.get(ast, "calls", [])

    # Check for file operations without proper cleanup
    file_ops = ["File.open", "File.open!", "TCP.connect", "SSL.connect"]

    opens_resource = Enum.any?(calls, fn call ->
      Enum.any?(file_ops, &String.contains?(call, &1))
    end)

    # Check if there's a corresponding close/ensure pattern
    has_cleanup = String.contains?(content, "File.close") or
                 String.contains?(content, "ensure") or
                 String.contains?(content, "after") or
                 String.match?(content, ~r/try.*after.*end/m)

    opens_resource and not has_cleanup
  end

  defp contains_unsafe_operations?(ast) do
    # Detect unsafe type conversions and operations
    content = Map.get(ast, "content", "")
    calls = Map.get(ast, "calls", [])

    # Check for unsafe type operations
    unsafe_patterns = [
      "String.to_atom",  # Can create atoms from user input
      "String.to_existing_atom",  # Better but still risky
      "apply",  # Dynamic function calls
      "eval",  # Code evaluation
      "Code.eval_string"  # String evaluation
    ]

    has_unsafe_calls = Enum.any?(calls, fn call ->
      Enum.any?(unsafe_patterns, &String.contains?(call, &1))
    end)

    # Check for unsafe operations in content
    unsafe_in_content = String.match?(content, ~r/:\s*[^:]\s*\([^)]*\)\s*\./) or
                       String.match?(content, ~r/struct\s*\.\.\*.*%/)

    has_unsafe_calls or unsafe_in_content
  end

  defp contains_async_issues?(ast) do
    # Detect common async/await issues
    content = Map.get(ast, "content", "")
    calls = Map.get(ast, "calls", [])

    # Check for Task operations without proper error handling
    async_ops = ["Task.start", "Task.async", "spawn", "spawn_link"]

    has_async = Enum.any?(calls, fn call ->
      Enum.any?(async_ops, &String.contains?(call, &1))
    end)

    # Check if there's proper supervision or error handling
    has_supervision = String.contains?(content, "Supervisor") or
                     String.contains?(content, "GenServer") or
                     String.contains?(content, "Process.monitor")

    # Check for unawaited async operations
    unawaited_tasks = String.match?(content, ~r/Task\.async(?!\s*\|>)/) or
                     String.match?(content, ~r/spawn(?!\s*\(|.*monitor)/)

    has_async and (not has_supervision or unawaited_tasks)
  end
end

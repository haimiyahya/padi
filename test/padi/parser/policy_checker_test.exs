defmodule Padi.Parser.PolicyCheckerTest do
  use ExUnit.Case

  alias Padi.Parser.PolicyChecker

  setup do
    # The GenServers are already started by the application
    :ok
  end

  describe "policy loading" do
    test "loads default policy" do
      assert {:ok, policy} = PolicyChecker.load_policy("priv/.padi-policy.json")
      assert policy.version == "1.0.0"
      assert is_list(policy.anti_patterns)
    end

    test "returns error for missing file" do
      assert {:error, :not_found} = PolicyChecker.load_policy("nonexistent.json")
    end
  end

  describe "validation" do
    test "accepts code without violations" do
      safe_code = """
      defmodule SafeCode do
        def process(data) do
          CryptoWrapper.hash(:sha3, data)
        end
      end
      """

      assert :ok = PolicyChecker.validate_patch("test.ex", safe_code)
    end

    test "rejects raw crypto calls" do
      unsafe_code = """
      defmodule UnsafeCode do
        def process(data) do
          :crypto.hash(:sha, data)
        end
      end
      """

      assert {:error, :policy_violation, violations} =
        PolicyChecker.validate_patch("test.ex", unsafe_code)

      assert length(violations) > 0

      violation = List.first(violations)
      assert violation.rule_name == "no_raw_crypto_calls"
      assert violation.action == "reject"
    end

    test "provides recommendations for violations" do
      unsafe_code = ":crypto.hash(:sha, data)"

      assert {:error, :policy_violation, [violation]} =
        PolicyChecker.validate_patch("test.ex", unsafe_code)

      recommendation = PolicyChecker.get_recommendation(violation)
      assert is_binary(recommendation.reason)
      assert is_binary(recommendation.suggested_fix)
    end
  end

  describe "anti-pattern detection" do
    test "detects hardcoded secrets pattern" do
      code_with_secret = """
      password = "supersecret123"
      api_key = "sk-1234567890"
      """

      {:error, :policy_violation, violations} =
        PolicyChecker.validate_patch("test.ex", code_with_secret)

      assert Enum.any?(violations, fn v ->
        v.rule_name == "no_hardcoded_secrets"
      end)
    end

    test "detects debug print statements" do
      debug_code = """
      IO.inspect(debug_value)
      IO.puts("Debug info")
      dbg(variable)
      """

      {:error, :policy_violation, violations} =
        PolicyChecker.validate_patch("test.ex", debug_code)

      assert Enum.any?(violations, fn v ->
        v.rule_name == "no_debug_prints_in_production"
      end)
    end
  end
end

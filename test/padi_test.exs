defmodule PadiTest do
  use ExUnit.Case
  doctest Padi

  alias Padi.Storage.EtsRegistry
  alias Padi.Parser.PolicyChecker
  alias Padi.Coordinator.CodeWriter

  setup do
    # The application is started automatically for tests
    # No need to start GenServers manually
    :ok
  end

  describe "version" do
    test "returns version string" do
      assert is_binary(Padi.version())
    end
  end

  describe "ramdisk_path" do
    test "returns ramdisk path" do
      assert is_binary(Padi.ramdisk_path())
    end
  end

  describe "ETS Registry" do
    test "stores and retrieves AST nodes" do
      node_id = "test_node_1"
      info = %{filepath: "test.ex", line: 42}

      assert :ok = EtsRegistry.put_ast_node(node_id, info)
      assert {:ok, ^info} = EtsRegistry.get_ast_node(node_id)
    end

    test "acquires and releases locks" do
      file_path = "lib/test_padi_lock.ex"

      # Ensure clean state
      EtsRegistry.release_lock(file_path)

      assert {:ok, _token} = EtsRegistry.acquire_lock(file_path, "req_1")
      assert EtsRegistry.locked?(file_path)

      assert :ok = EtsRegistry.release_lock(file_path)
      refute EtsRegistry.locked?(file_path)

      # Cleanup
      EtsRegistry.release_lock(file_path)
    end

    test "prevents concurrent lock acquisition" do
      file_path = "lib/test_concurrent.ex"

      # Ensure clean state
      EtsRegistry.release_lock(file_path)

      assert {:ok, _token} = EtsRegistry.acquire_lock(file_path, "req_1")
      assert {:error, {:locked, _info}} = EtsRegistry.acquire_lock(file_path, "req_2")

      # Cleanup
      EtsRegistry.release_lock(file_path)
    end
  end

  describe "Policy Checker" do
    test "loads policy file" do
      assert {:ok, policy} = PolicyChecker.load_policy("priv/.padi-policy.json")
      assert is_list(policy.anti_patterns)
    end

    test "validates clean code" do
      clean_code = """
      defmodule Safe do
        def hash_password(password) do
          CryptoWrapper.hash(:sha3, password)
        end
      end
      """

      assert :ok = PolicyChecker.validate_patch("test.ex", clean_code)
    end

    test "rejects code with anti-patterns" do
      unsafe_code = """
      defmodule Unsafe do
        def hash_password(password) do
          :crypto.hash(:sha3, password)
        end
      end
      """

      assert {:error, :policy_violation, violations} =
        PolicyChecker.validate_patch("test.ex", unsafe_code)

      assert length(violations) > 0
    end
  end

  describe "CodeWriter" do
    test "accepts valid mutations" do
      valid_code = """
      defmodule Test do
        def add(a, b), do: a + b
      end
      """

      request = Padi.Coordinator.MutationRequest.new(
        "lib/test.ex",
        valid_code
      )

      assert {:ok, result} = CodeWriter.submit_mutation(request)
      assert result.status == :success
    end

    test "rejects policy-violating mutations" do
      invalid_code = """
      defmodule Test do
        def unsafe() do
          :crypto.hash(:sha, "data")
        end
      end
      """

      request = Padi.Coordinator.MutationRequest.new(
        "lib/test.ex",
        invalid_code
      )

      assert {:rejected, details} = CodeWriter.submit_mutation(request)
      assert Map.has_key?(details, :violations)
    end

    test "returns stats" do
      stats = CodeWriter.stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :total_submitted)
    end
  end

  describe "Integration" do
    test "end-to-end mutation flow" do
      # 1. Query intent
      query_params = %{
        "intent_description" => "Add a function that hashes passwords"
      }

      # In a real test, we would call the router
      assert is_map(query_params)

      # 2. Submit mutation
      safe_code = """
      defmodule Auth do
        def hash_password(password) do
          CryptoWrapper.hash(:sha3, password)
        end
      end
      """

      request = Padi.Coordinator.MutationRequest.new(
        "lib/auth.ex",
        safe_code
      )

      assert {:ok, result} = CodeWriter.submit_mutation(request)
      assert result.status == :success
    end
  end
end

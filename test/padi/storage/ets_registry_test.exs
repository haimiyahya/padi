defmodule Padi.Storage.EtsRegistryTest do
  use ExUnit.Case

  alias Padi.Storage.EtsRegistry

  setup do
    # The GenServers are already started by the application
    :ok
  end

  describe "AST node operations" do
    test "put and get AST node" do
      node_id = "node_test_1"
      info = %{
        filepath: "lib/test.ex",
        line: 10,
        node_type: :function_definition
      }

      assert :ok = EtsRegistry.put_ast_node(node_id, info)
      assert {:ok, retrieved} = EtsRegistry.get_ast_node(node_id)
      assert retrieved.filepath == "lib/test.ex"
    end

    test "returns error for non-existent node" do
      assert :error = EtsRegistry.get_ast_node("nonexistent")
    end

    test "overwrites existing node" do
      node_id = "node_test_2"

      EtsRegistry.put_ast_node(node_id, %{original: true})
      EtsRegistry.put_ast_node(node_id, %{updated: true})

      assert {:ok, info} = EtsRegistry.get_ast_node(node_id)
      assert Map.has_key?(info, :updated)
      refute Map.has_key?(info, :original)
    end
  end

  describe "Lock operations" do
    test "acquire and release lock" do
      file_path = "lib/locked.ex"

      assert {:ok, token} = EtsRegistry.acquire_lock(file_path, "req_1")
      assert is_reference(token)

      assert :ok = EtsRegistry.release_lock(file_path)
      refute EtsRegistry.locked?(file_path)
    end

    test "cannot acquire locked file" do
      file_path = "lib/contention.ex"

      assert {:ok, _token} = EtsRegistry.acquire_lock(file_path, "req_1")
      assert {:error, {:locked, _info}} = EtsRegistry.acquire_lock(file_path, "req_2")
    end

    test "can acquire lock after release" do
      file_path = "lib/reuse.ex"

      {:ok, _token} = EtsRegistry.acquire_lock(file_path, "req_1")
      :ok = EtsRegistry.release_lock(file_path)

      assert {:ok, _token2} = EtsRegistry.acquire_lock(file_path, "req_2")
    end
  end

  describe "stats" do
    test "returns cache statistics" do
      EtsRegistry.put_ast_node("node1", %{data: 1})
      EtsRegistry.put_ast_node("node2", %{data: 2})

      EtsRegistry.acquire_lock("file1.ex", "req_1")

      stats = EtsRegistry.stats()
      assert stats.ast_nodes >= 2
      assert stats.locks >= 1
    end
  end

  describe "clear" do
    test "clears all caches" do
      EtsRegistry.put_ast_node("node1", %{data: 1})
      EtsRegistry.acquire_lock("file1.ex", "req_1")

      assert :ok = EtsRegistry.clear()

      stats = EtsRegistry.stats()
      assert stats.ast_nodes == 0
      assert stats.locks == 0
    end
  end
end

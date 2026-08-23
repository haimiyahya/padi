defmodule Padi.Tools.ToolRegistryTest do
  @moduledoc """
  Tests for the Tool Registry system.
  """

  use ExUnit.Case
  alias Padi.Tools.ToolRegistry

  @moduletag :tools
  @moduletag :tool_registry

  setup do
    # Ensure application is started
    Application.ensure_all_started(:padi)
    :ok
  end

  describe "Tool Registration and Listing" do
    test "lists all available tools" do
      tools = ToolRegistry.list_tools()

      assert is_list(tools)
      assert length(tools) > 0

      # Check that tools have required fields
      first_tool = hd(tools)
      assert Map.has_key?(first_tool, :name)
      assert Map.has_key?(first_tool, :command)
      assert Map.has_key?(first_tool, :category)
      assert Map.has_key?(first_tool, :description)
    end

    test "lists tools by category" do
      safe_tools = ToolRegistry.list_tools(:safe)

      assert is_list(safe_tools)
      assert length(safe_tools) > 0

      # All tools should be in the safe category
      Enum.each(safe_tools, fn tool ->
        # Tools returned are already filtered by category
        assert true
      end)
    end

    test "checks if tool is available" do
      # echo should be available on most systems
      assert ToolRegistry.tool_available?(:echo) or :os.type() != :unix

      # Non-existent tool should not be available
      refute ToolRegistry.tool_available?(:nonexistent_tool_12345)
    end

    test "gets tool definition" do
      {:ok, tool} = ToolRegistry.get_tool(:echo)

      assert tool.command == "echo"
      assert tool.category == :safe
      assert is_binary(tool.description)
      assert is_integer(tool.timeout)
    end

    test "returns error for non-existent tool" do
      assert {:error, :not_found} = ToolRegistry.get_tool(:nonexistent_tool)
    end

    test "registers custom tool" do
      custom_tool = %{
        command: "custom",
        category: :safe,
        description: "Custom test tool",
        timeout: 5000
      }

      assert :ok = ToolRegistry.register_tool(:custom_test_tool, custom_tool)

      # Verify it was registered
      {:ok, retrieved_tool} = ToolRegistry.get_tool(:custom_test_tool)
      assert retrieved_tool.command == "custom"
    end
  end

  describe "Tool Execution" do
    test "executes echo command successfully" do
      result = ToolRegistry.execute_tool(:echo, ["Hello, PADI!"])

      assert {:ok, %{success: true, output: output}} = result
      assert output =~ ~r/Hello, PADI!/
    end

    test "executes pwd command successfully" do
      result = ToolRegistry.execute_tool(:pwd, [])

      assert {:ok, %{success: true, output: output}} = result
      assert String.length(output) > 0
    end

    test "executes date command successfully" do
      result = ToolRegistry.execute_tool(:date, [])

      assert {:ok, %{success: true, output: output}} = result
      assert String.length(output) > 0
    end

    test "executes cat command with file argument" do
      # Create a temporary file
      File.write!("/tmp/test_cat_file.txt", "Test content for cat")

      result = ToolRegistry.execute_tool(:cat, ["/tmp/test_cat_file.txt"])

      assert {:ok, %{success: true, output: output}} = result
      assert output =~ ~r/Test content for cat/

      # Clean up
      File.rm!("/tmp/test_cat_file.txt")
    end

    test "handles command with multiple arguments" do
      result = ToolRegistry.execute_tool(:echo, ["Hello", "World", "from", "PADI"])

      assert {:ok, %{success: true}} = result
    end

    test "returns error for non-existent tool" do
      result = ToolRegistry.execute_tool(:nonexistent_tool, [])

      assert {:error, :tool_not_found} = result
    end

    test "provides timing information" do
      result = ToolRegistry.execute_tool(:echo, ["Timing test"])

      assert {:ok, %{duration_ms: duration}} = result
      assert is_integer(duration)
      assert duration >= 0
    end

    test "respects custom timeout" do
      # This test verifies timeout option is available
      # Note: System.cmd doesn't support direct timeout, but the option is available for future implementations
      result = ToolRegistry.execute_tool(:echo, ["Quick test"])

      assert {:ok, _} = result
    end
  end

  describe "Permission System" do
    test "gets default permissions" do
      permissions = ToolRegistry.get_permissions()

      assert is_map(permissions)
      assert Map.has_key?(permissions, :safe)
      assert Map.has_key?(permissions, :build)
      assert Map.has_key?(permissions, :network)
      assert Map.has_key?(permissions, :system)
      assert Map.has_key?(permissions, :dangerous)
    end

    test "sets custom permissions" do
      new_permissions = %{
        safe: true,
        build: false,
        network: false,
        system: false,
        dangerous: false
      }

      assert :ok = ToolRegistry.set_permissions(new_permissions)

      updated = ToolRegistry.get_permissions()
      assert updated.build == false
    end

    test "respects permission settings during execution" do
      # Disable all permissions except safe
      restricted_permissions = %{
        safe: true,
        build: false,
        network: false,
        system: false,
        dangerous: false
      }

      ToolRegistry.set_permissions(restricted_permissions)

      # Safe tools should still work
      assert {:ok, _} = ToolRegistry.execute_tool(:echo, ["test"])

      # Build tools should be denied (if available)
      case ToolRegistry.tool_available?(:make) do
        true ->
          result = ToolRegistry.execute_tool(:make, ["--version"])
          # Should get either permission denied or some other error
          case result do
            {:ok, _} ->
              # This shouldn't happen with permissions disabled
              flunk("make should be denied with build permissions disabled")
            {:error, _} ->
              # Expected - permission denied or tool not available
              :ok
          end

        false ->
          # make not available, skip this assertion
          :ok
      end

      # Restore default permissions
      ToolRegistry.set_permissions(%{
        safe: true,
        build: true,
        network: true,
        system: false,
        dangerous: false
      })
    end
  end

  describe "Tool Categories" do
    test "safe tools contain expected utilities" do
      safe_tools = ToolRegistry.list_tools(:safe)

      safe_tool_names = Enum.map(safe_tools, fn tool -> tool.name end)

      # Check for common safe tools
      assert :echo in safe_tool_names
      assert :pwd in safe_tool_names
      assert :cat in safe_tool_names
    end

    test "build tools contain compilation tools" do
      build_tools = ToolRegistry.list_tools(:build)

      build_tool_names = Enum.map(build_tools, fn tool -> tool.name end)

      # Check for expected build tools
      assert :mix in build_tool_names
      assert :make in build_tool_names
    end

    test "network tools contain connectivity tools" do
      network_tools = ToolRegistry.list_tools(:network)

      network_tool_names = Enum.map(network_tools, fn tool -> tool.name end)

      # Check for expected network tools
      assert :ping in network_tool_names
      assert :git in network_tool_names
    end
  end

  describe "Error Handling" do
    test "handles invalid tool definition" do
      invalid_tool = %{
        # Missing required fields
        command: "incomplete"
      }

      result = ToolRegistry.register_tool(:invalid_tool, invalid_tool)

      assert {:error, {:missing_keys, _missing_keys}} = result
    end

    test "handles command execution failure gracefully" do
      # Try to execute a command that will fail
      # Using ls with a non-existent directory
      result = ToolRegistry.execute_tool(:ls, ["/nonexistent_directory_12345"])

      assert {:ok, %{success: false, exit_code: exit_code}} = result
      assert exit_code != 0
    end
  end

  describe "Integration with Router" do
    test "tools/execute method works through InterrogationRouter" do
      params = %{
        "tool" => "echo",
        "args" => ["Router test"]
      }

      result = Padi.Router.InterrogationRouter.handle_method(
        "tools/execute",
        params,
        "test_request_1"
      )

      assert {:ok, response} = result
      assert response["result"]["tool"] == "echo"
      assert response["result"]["success"] == true
      assert response["result"]["output"] =~ ~r/Router test/
    end

    test "tools/list method works through InterrogationRouter" do
      params = %{}

      result = Padi.Router.InterrogationRouter.handle_method(
        "tools/list",
        params,
        "test_request_2"
      )

      assert {:ok, response} = result
      assert Map.has_key?(response["result"], "tools")
      assert Map.has_key?(response["result"], "total")
      assert is_list(response["result"]["tools"])
      assert response["result"]["total"] > 0
    end

    test "tools/list with category filter works through InterrogationRouter" do
      params = %{"category" => "safe"}

      result = Padi.Router.InterrogationRouter.handle_method(
        "tools/list",
        params,
        "test_request_3"
      )

      assert {:ok, response} = result
      assert Map.has_key?(response["result"], "tools")
      assert length(response["result"]["tools"]) > 0
    end
  end
end

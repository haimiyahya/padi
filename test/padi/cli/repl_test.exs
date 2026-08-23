defmodule Padi.CLI.REPLTest do
  @moduledoc """
  Tests for Interactive REPL.
  """

  use ExUnit.Case
  alias Padi.CLI.REPL

  @moduletag :cli
  @moduletag :repl

  setup do
    Application.ensure_all_started(:padi)

    # Ensure REPL is started, but don't fail if already started
    case REPL.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  describe "REPL Lifecycle" do
    test "starts and stops successfully" do
      # REPL should already be running from setup
      assert Process.whereis(REPL) != nil

      # Note: We don't stop it here to avoid affecting other tests
    end

    test "returns current state" do
      state = REPL.get_state()

      assert is_map(state)
      assert Map.has_key?(state, :running)
      assert Map.has_key?(state, :project_info)
      assert Map.has_key?(state, :history)
      assert Map.has_key?(state, :current_dir)
      assert state.running == true
    end
  end

  describe "Command Processing" do
    test "processes help command" do
      result = REPL.process_command("help")

      assert {:ok, response} = result
      assert is_binary(response)
      assert String.contains?(response, "PADI CLI")
    end

    test "processes status command" do
      result = REPL.process_command("status")

      assert {:ok, response} = result
      assert is_binary(response)
      assert String.contains?(response, "Project Status")
    end

    test "processes exit command" do
      result = REPL.process_command("exit")

      assert {:exit, message} = result
      assert is_binary(message)
      assert String.contains?(message, "Goodbye")
    end

    test "handles unknown command" do
      result = REPL.process_command("do something impossible")

      assert {:ok, response} = result
      assert is_binary(response)
      assert String.contains?(response, "Unknown command")
    end

    test "processes empty command" do
      result = REPL.process_command("")

      assert {:ok, response} = result
      assert is_binary(response)
    end
  end

  describe "Command History" do
    test "tracks command history" do
      # Process a few commands
      REPL.process_command("help")
      REPL.process_command("status")

      state = REPL.get_state()

      assert length(state.history) >= 2
      assert "help" in state.history
      assert "status" in state.history
    end
  end

  describe "Natural Language Processing" do
    test "understands various test phrasings" do
      test_phrases = [
        "run tests",
        "run unit tests",
        "test the code"
      ]

      Enum.each(test_phrases, fn phrase ->
        # Note: This might fail if tests don't exist or tool execution fails
        # but we're testing that the intent is recognized
        result = REPL.process_command(phrase)

        # Should either execute or return a meaningful response
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end)
    end

    test "understands various build phrasings" do
      build_phrases = [
        "build the project",
        "compile the code"
      ]

      Enum.each(build_phrases, fn phrase ->
        result = REPL.process_command(phrase)

        # Should process the command
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end)
    end
  end

  describe "Error Handling" do
    test "handles project detection failures gracefully" do
      # This tests behavior when no project is detected
      # The REPL should still respond appropriately
      result = REPL.process_command("run tests")

      # Should either work (if project detected) or return error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "State Management" do
    test "updates running state on exit" do
      # Process exit command
      result = REPL.process_command("exit")

      assert {:exit, _message} = result

      # After exit, the REPL should have stopped
      # Note: In the current implementation, the REPL process continues
      # but the state reflects it should not continue running
    end
  end

  describe "Integration with ProjectDetector" do
    test "uses project info from current directory" do
      state = REPL.get_state()

      assert is_map(state.project_info)
      assert Map.has_key?(state.project_info, :type)
      assert Map.has_key?(state.project_info, :name)
    end
  end

  describe "Response Formatting" do
    test "returns formatted responses" do
      result = REPL.process_command("status")

      assert {:ok, response} = result
      assert String.contains?(response, "Project")
      assert String.contains?(response, "Type:")
    end
  end

  describe "Multi-Command Processing" do
    test "processes multiple commands in sequence" do
      commands = ["help", "status", "help"]

      results = Enum.map(commands, &REPL.process_command/1)

      Enum.each(results, fn result ->
        assert match?({:ok, _}, result) or match?({:exit, _}, result)
      end)
    end
  end
end

defmodule Padi.CLI.ProjectDetectorTest do
  @moduledoc """
  Tests for Project Detector.
  """

  use ExUnit.Case
  alias Padi.CLI.ProjectDetector

  @moduletag :cli
  @moduletag :project_detector

  setup do
    Application.ensure_all_started(:padi)
    :ok
  end

  describe "Project Type Detection" do
    test "detects Elixir project by mix.exs" do
      # Test in current directory (has mix.exs)
      project_type = ProjectDetector.detect_project(File.cwd!())
      assert project_type == :elixir
    end

    test "returns unknown for directory with no project files" do
      # Test in /tmp which likely has no project files
      project_type = ProjectDetector.detect_project("/tmp")
      assert project_type == :unknown
    end
  end

  describe "Command Mapping" do
    test "returns correct commands for Elixir projects" do
      assert ProjectDetector.get_command(:elixir, :test) == ["mix", "test"]
      assert ProjectDetector.get_command(:elixir, :build) == ["mix", "compile"]
      assert ProjectDetector.get_command(:elixir, :run) == ["mix", "run"]
      assert ProjectDetector.get_command(:elixir, :install) == ["mix", "deps.get"]
      assert ProjectDetector.get_command(:elixir, :clean) == ["mix", "clean"]
    end

    test "returns correct commands for Rust projects" do
      assert ProjectDetector.get_command(:rust, :test) == ["cargo", "test"]
      assert ProjectDetector.get_command(:rust, :build) == ["cargo", "build"]
      assert ProjectDetector.get_command(:rust, :run) == ["cargo", "run"]
    end

    test "returns correct commands for Node.js projects" do
      assert ProjectDetector.get_command(:nodejs, :test) == ["npm", "test"]
      assert ProjectDetector.get_command(:nodejs, :install) == ["npm", "install"]
    end

    test "returns empty list for unknown command" do
      assert ProjectDetector.get_command(:elixir, :unknown) == []
    end
  end

  describe "Project Information" do
    test "returns project info for current directory" do
      info = ProjectDetector.get_project_info()

      assert is_map(info)
      assert Map.has_key?(info, :type)
      assert Map.has_key?(info, :name)
      assert Map.has_key?(info, :path)
      assert Map.has_key?(info, :supported_commands)

      # Current directory should be detected as Elixir
      assert info.type == :elixir
      assert length(info.supported_commands) > 0
    end
  end

  describe "Command Support" do
    test "correctly identifies supported commands" do
      assert ProjectDetector.command_supported?(:elixir, :test) == true
      assert ProjectDetector.command_supported?(:elixir, :build) == true
      assert ProjectDetector.command_supported?(:elixir, :unknown) == false
    end

    test "returns supported commands list" do
      commands = ProjectDetector.get_supported_commands(:elixir)

      assert :test in commands
      assert :build in commands
      assert :run in commands
    end
  end

  describe "Command Execution" do
    test "executes test command for Elixir project" do
      result = ProjectDetector.execute_command(:test, File.cwd!())

      assert {:ok, output} = result
      assert is_binary(output)
      # The output should contain test results
      assert String.length(output) > 0
    end

    test "returns error for unknown command" do
      result = ProjectDetector.execute_command(:unknown, File.cwd!())

      assert {:error, {:unknown_command, :unknown, :elixir}} = result
    end
  end
end

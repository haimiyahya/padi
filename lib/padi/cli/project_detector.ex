defmodule Padi.CLI.ProjectDetector do
  @moduledoc """
  Project type detection for CLI commands.

  Detects the project type based on the presence of configuration files
  and provides appropriate command mappings for common operations.
  """

  @type project_type :: :elixir | :rust | :nodejs | :python | :go | :java | :unknown
  @type command_name :: :test | :build | :run | :install | :clean | :unknown

  # Project detection patterns
  @project_patterns [
   elixir: ["mix.exs"],
    rust: ["Cargo.toml"],
    nodejs: ["package.json", "package-lock.json", "yarn.lock"],
    python: ["requirements.txt", "setup.py", "pyproject.toml", "Pipfile", "poetry.lock"],
    go: ["go.mod"],
    java: ["pom.xml", "build.gradle", "build.gradle.kts"]
  ]

  # Command mappings for each project type
  @command_mappings %{
    elixir: %{
      test: ["mix", "test"],
      build: ["mix", "compile"],
      run: ["mix", "run"],
      install: ["mix", "deps.get"],
      clean: ["mix", "clean"]
    },
    rust: %{
      test: ["cargo", "test"],
      build: ["cargo", "build"],
      run: ["cargo", "run"],
      install: ["cargo", "build"],
      clean: ["cargo", "clean"]
    },
    nodejs: %{
      test: ["npm", "test"],
      build: ["npm", "run", "build"],
      run: ["npm", "start"],
      install: ["npm", "install"],
      clean: ["rm", "-rf", "node_modules"]
    },
    python: %{
      test: ["python", "-m", "pytest"],
      build: ["python", "-m", "build"],
      run: ["python"],
      install: ["pip", "install"],
      clean: ["find", ".", "-type", "d", "-name", "__pycache__", "-exec", "rm", "-rf", "{}", "+"]
    },
    go: %{
      test: ["go", "test", "./..."],
      build: ["go", "build"],
      run: ["go", "run", "."],
      install: ["go", "mod", "tidy"],
      clean: ["go", "clean"]
    },
    java: %{
      test: ["mvn", "test"],
      build: ["mvn", "compile"],
      run: ["mvn", "exec:java"],
      install: ["mvn", "install"],
      clean: ["mvn", "clean"]
    }
  }

  @doc """
  Detect the project type from the current directory.

  Returns the project type atom or :unknown if no recognized pattern is found.
  """
  @spec detect_project(String.t()) :: project_type()
  def detect_project(path \\ File.cwd!()) do
    Enum.find(@project_patterns, fn {_type, patterns} ->
      Enum.any?(patterns, fn pattern ->
        File.exists?(Path.join(path, pattern))
      end)
    end)
    |> case do
      {type, _patterns} -> type
      nil -> :unknown
    end
  end

  @doc """
  Get the command for a given project type and operation.

  Returns a list of command arguments suitable for System.cmd or ToolRegistry.execute_tool.
  """
  @spec get_command(project_type(), command_name()) :: [String.t()]
  def get_command(project_type, command_name) do
    get_in(@command_mappings, [project_type, command_name]) || []
  end

  @doc """
  Execute a command for the current project.

  Automatically detects project type and executes the appropriate command.
  """
  @spec execute_command(command_name(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def execute_command(command_name, path \\ File.cwd!()) do
    project_type = detect_project(path)
    command = get_command(project_type, command_name)

    if command == [] do
      {:error, {:unknown_command, command_name, project_type}}
    else
      case Padi.Tools.ToolRegistry.execute_tool(hd(command), tl(command)) do
        {:ok, result} -> {:ok, result.output}
        error -> error
      end
    end
  end

  @doc """
  Get project information for display.
  """
  @spec get_project_info(String.t()) :: map()
  def get_project_info(path \\ File.cwd!()) do
    project_type = detect_project(path)

    # Try to get project name from common config files
    project_name = extract_project_name(path, project_type)

    %{
      type: project_type,
      name: project_name,
      path: path,
      supported_commands: get_supported_commands(project_type)
    }
  end

  @doc """
  Get all supported commands for a project type.
  """
  @spec get_supported_commands(project_type()) :: [atom()]
  def get_supported_commands(project_type) do
    Map.get(@command_mappings, project_type, %{})
    |> Map.keys()
  end

  @doc """
  Check if a command is supported for the given project type.
  """
  @spec command_supported?(project_type(), command_name()) :: boolean()
  def command_supported?(project_type, command_name) do
    get_command(project_type, command_name) != []
  end

  # Private helpers

  defp extract_project_name(path, :elixir) do
    mix_exs = Path.join(path, "mix.exs")
    if File.exists?(mix_exs) do
      case File.read(mix_exs) do
        {:ok, content} ->
          # Try to extract project name from mix.exs
          Regex.run(~r/[pP]roject.*\[.*name:\s*:"([^"]+)"/, content, capture: :all_but_first)
          |> case do
            [name | _] -> name
            _ -> Path.basename(path)
          end
        _ -> Path.basename(path)
      end
    else
      Path.basename(path)
    end
  end

  defp extract_project_name(path, :rust) do
    cargo_toml = Path.join(path, "Cargo.toml")
    if File.exists?(cargo_toml) do
      case File.read(cargo_toml) do
        {:ok, content} ->
          # Try to extract package name from Cargo.toml
          Regex.run(~r/name\s*=\s*"([^"]+)"/, content, capture: :all_but_first)
          |> case do
            [name | _] -> name
            _ -> Path.basename(path)
          end
        _ -> Path.basename(path)
      end
    else
      Path.basename(path)
    end
  end

  defp extract_project_name(path, :nodejs) do
    package_json = Path.join(path, "package.json")
    if File.exists?(package_json) do
      case File.read(package_json) do
        {:ok, content} ->
          # Try to extract package name from package.json
          Regex.run(~r/"name"\s*:\s*"([^"]+)"/, content, capture: :all_but_first)
          |> case do
            [name | _] -> name
            _ -> Path.basename(path)
          end
        _ -> Path.basename(path)
      end
    else
      Path.basename(path)
    end
  end

  defp extract_project_name(path, :python) do
    # For Python, use the directory name
    Path.basename(path)
  end

  defp extract_project_name(path, :go) do
    go_mod = Path.join(path, "go.mod")
    if File.exists?(go_mod) do
      case File.read(go_mod) do
        {:ok, content} ->
          # Try to extract module name from go.mod
          Regex.run(~r/module\s+([^\s]+)/, content, capture: :all_but_first)
          |> case do
            [name | _] -> Path.basename(name)
            _ -> Path.basename(path)
          end
        _ -> Path.basename(path)
      end
    else
      Path.basename(path)
    end
  end

  defp extract_project_name(path, :java) do
    # For Java, try to get artifactId from pom.xml
    pom_xml = Path.join(path, "pom.xml")
    if File.exists?(pom_xml) do
      case File.read(pom_xml) do
        {:ok, content} ->
          Regex.run(~r/<artifactId>([^<]+)<\/artifactId>/, content, capture: :all_but_first)
          |> case do
            [name | _] -> name
            _ -> Path.basename(path)
          end
        _ -> Path.basename(path)
      end
    else
      Path.basename(path)
    end
  end

  defp extract_project_name(path, :unknown) do
    Path.basename(path)
  end
end

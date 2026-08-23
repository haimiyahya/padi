defmodule Padi.Tools.ToolRegistry do
  @moduledoc """
  Tool Registry for PADI.

  Manages registration, permissions, and execution of external tools and commands.
  Provides a secure, controlled environment for agents to execute system commands.

  ## Security Model

  Tools are organized by category with different permission levels:
  - **safe**: Always allowed (e.g., echo, pwd, date)
  - **build**: Requires build permission (e.g., make, cargo, mix)
  - **network**: Requires network permission (e.g., curl, ping, git)
  - **system**: Requires system permission (e.g., systemctl, service)
  - **dangerous**: Never allowed (e.g., rm, mkfs, dd)

  ## Usage

  ```elixir
  # Register a custom tool
  ToolRegistry.register_tool(:my_tool, %{
    command: "mycommand",
    category: :safe,
    description: "My custom tool",
    timeout: 5000
  })

  # Execute a tool
  ToolRegistry.execute_tool(:echo, ["Hello, World!"])
  # => {:ok, "Hello, World!", %{exit_code: 0, duration_ms: 1}}

  # Check if a tool is available
  ToolRegistry.tool_available?(:ping)
  # => true
  """

  use GenServer
  require Logger

  # Tool categories
  @categories [:safe, :build, :network, :system, :dangerous]

  # Default tool definitions
  @default_tools %{
    # Safe tools - always allowed
    echo: %{
      command: "echo",
      category: :safe,
      description: "Print text to stdout",
      timeout: 2000
    },
    pwd: %{
      command: "pwd",
      category: :safe,
      description: "Print working directory",
      timeout: 1000
    },
    date: %{
      command: "date",
      category: :safe,
      description: "Print current date and time",
      timeout: 1000
    },
    cat: %{
      command: "cat",
      category: :safe,
      description: "Read file contents",
      timeout: 5000,
      requires_args: true
    },
    ls: %{
      command: "ls",
      category: :safe,
      description: "List directory contents",
      timeout: 3000
    },
    head: %{
      command: "head",
      category: :safe,
      description: "Print first lines of file",
      timeout: 5000
    },
    tail: %{
      command: "tail",
      category: :safe,
      description: "Print last lines of file",
      timeout: 5000
    },
    wc: %{
      command: "wc",
      category: :safe,
      description: "Count lines, words, characters",
      timeout: 3000
    },
    grep: %{
      command: "grep",
      category: :safe,
      description: "Search for patterns in files",
      timeout: 10000
    },
    find: %{
      command: "find",
      category: :safe,
      description: "Search for files in directory hierarchy",
      timeout: 15000
    },

    # Build tools
    make: %{
      command: "make",
      category: :build,
      description: "Build automation tool",
      timeout: 60000,
      requires_permission: :build
    },
    cargo: %{
      command: "cargo",
      category: :build,
      description: "Rust package manager and build tool",
      timeout: 120000,
      requires_permission: :build
    },
    mix: %{
      command: "mix",
      category: :build,
      description: "Elixir build tool",
      timeout: 120000,
      requires_permission: :build
    },
    npm: %{
      command: "npm",
      category: :build,
      description: "Node.js package manager",
      timeout: 120000,
      requires_permission: :build
    },
    yarn: %{
      command: "yarn",
      category: :build,
      description: "Alternative Node.js package manager",
      timeout: 120000,
      requires_permission: :build
    },
    gcc: %{
      command: "gcc",
      category: :build,
      description: "C compiler",
      timeout: 60000,
      requires_permission: :build
    },
    clang: %{
      command: "clang",
      category: :build,
      description: "C/C++ compiler",
      timeout: 60000,
      requires_permission: :build
    },

    # Network tools
    ping: %{
      command: "ping",
      category: :network,
      description: "Send ICMP echo requests",
      timeout: 10000,
      requires_permission: :network
    },
    curl: %{
      command: "curl",
      category: :network,
      description: "Transfer data with URLs",
      timeout: 30000,
      requires_permission: :network
    },
    wget: %{
      command: "wget",
      category: :network,
      description: "Download files from the web",
      timeout: 60000,
      requires_permission: :network
    },
    git: %{
      command: "git",
      category: :network,
      description: "Version control system",
      timeout: 30000,
      requires_permission: :network
    },
    ssh: %{
      command: "ssh",
      category: :network,
      description: "SSH client",
      timeout: 60000,
      requires_permission: :network
    },

    # Test tools
    pytest: %{
      command: "pytest",
      category: :build,
      description: "Python testing framework",
      timeout: 120000,
      requires_permission: :build
    },
    junit: %{
      command: "junit",
      category: :build,
      description: "Java testing framework",
      timeout: 120000,
      requires_permission: :build
    },

    # Documentation tools
    asciidoc: %{
      command: "asciidoc",
      category: :safe,
      description: "AsciiDoc text processor",
      timeout: 10000
    },
    pandoc: %{
      command: "pandoc",
      category: :safe,
      description: "Universal document converter",
      timeout: 15000
    },
    doxygen: %{
      command: "doxygen",
      category: :safe,
      description: "Documentation generator",
      timeout: 30000
    },

    # System tools
    systemctl: %{
      command: "systemctl",
      category: :system,
      description: "System service manager",
      timeout: 10000,
      requires_permission: :system
    },
    service: %{
      command: "service",
      category: :system,
      description: "System service control",
      timeout: 10000,
      requires_permission: :system
    },

    # Development tools
    docker: %{
      command: "docker",
      category: :system,
      description: "Container platform",
      timeout: 60000,
      requires_permission: :system
    },
    kubectl: %{
      command: "kubectl",
      category: :network,
      description: "Kubernetes control",
      timeout: 30000,
      requires_permission: :network
    }
  }

  # Public API

  @doc """
  Start the tool registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a custom tool.
  """
  def register_tool(tool_name, tool_def) when is_atom(tool_name) and is_map(tool_def) do
    GenServer.call(__MODULE__, {:register_tool, tool_name, tool_def})
  end

  @doc """
  Check if a tool is available.
  """
  def tool_available?(tool_name) when is_atom(tool_name) do
    GenServer.call(__MODULE__, {:tool_available?, tool_name})
  end

  @doc """
  Get tool definition.
  """
  def get_tool(tool_name) when is_atom(tool_name) do
    GenServer.call(__MODULE__, {:get_tool, tool_name})
  end

  @doc """
  List all available tools.
  """
  def list_tools do
    GenServer.call(__MODULE__, :list_tools)
  end

  @doc """
  List tools by category.
  """
  def list_tools(category) when category in @categories do
    GenServer.call(__MODULE__, {:list_tools, category})
  end

  @doc """
  Execute a tool with arguments.
  """
  def execute_tool(tool_name, args \\ [], opts \\ []) do
    GenServer.call(__MODULE__, {:execute_tool, tool_name, args, opts}, :infinity)
  end

  @doc """
  Set permission level for tool execution.
  """
  def set_permissions(permissions) when is_map(permissions) do
    GenServer.call(__MODULE__, {:set_permissions, permissions})
  end

  @doc """
  Get current permission settings.
  """
  def get_permissions do
    GenServer.call(__MODULE__, :get_permissions)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      tools: @default_tools,
      permissions: default_permissions(),
      execution_history: []
    }

    Logger.info("ToolRegistry initialized with #{map_size(state.tools)} tools")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_tool, tool_name, tool_def}, _from, state) do
    # Validate tool definition
    case validate_tool_def(tool_def) do
      :ok ->
        new_state = %{state | tools: Map.put(state.tools, tool_name, tool_def)}
        Logger.debug("Registered tool: #{tool_name}")
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:tool_available?, tool_name}, _from, state) do
    available = Map.has_key?(state.tools, tool_name) and
                tool_executable?(Map.get(state.tools, tool_name))
    {:reply, available, state}
  end

  @impl true
  def handle_call({:get_tool, tool_name}, _from, state) do
    case Map.get(state.tools, tool_name) do
      nil -> {:reply, {:error, :not_found}, state}
      tool -> {:reply, {:ok, tool}, state}
    end
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    tools = Enum.map(state.tools, fn {name, def} ->
      %{
        name: name,
        command: def.command,
        category: def.category,
        description: def.description
      }
    end)
    {:reply, tools, state}
  end

  @impl true
  def handle_call({:list_tools, category}, _from, state) do
    tools = Enum.filter(state.tools, fn {_name, def} ->
      def.category == category
    end)

    formatted = Enum.map(tools, fn {name, def} ->
      %{
        name: name,
        command: def.command,
        description: def.description
      }
    end)

    {:reply, formatted, state}
  end

  @impl true
  def handle_call({:execute_tool, tool_name, args, opts}, _from, state) do
    case Map.get(state.tools, tool_name) do
      nil ->
        {:reply, {:error, :tool_not_found}, state}

      tool_def ->
        # Check permissions
        case check_permissions(tool_def, state.permissions) do
          :ok ->
            # Execute the tool
            result = do_execute_tool(tool_name, tool_def, args, opts)

            # Log execution
            log_execution(tool_name, args, result)

            {:reply, result, state}

          {:error, reason} ->
            Logger.warning("Tool execution denied: #{tool_name} - #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:set_permissions, permissions}, _from, state) do
    new_state = %{state | permissions: permissions}
    Logger.info("Updated tool permissions")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_permissions, _from, state) do
    {:reply, state.permissions, state}
  end

  # Private helpers

  defp default_permissions do
    %{
      safe: true,
      build: true,
      network: true,
      system: false,
      dangerous: false
    }
  end

  defp validate_tool_def(tool_def) do
    required_keys = [:command, :category, :description, :timeout]
    missing_keys = Enum.reject(required_keys, fn key -> Map.has_key?(tool_def, key) end)

    case missing_keys do
      [] -> :ok
      _ -> {:error, {:missing_keys, missing_keys}}
    end
  end

  defp tool_executable?(tool_def) do
    case System.find_executable(tool_def.command) do
      nil -> false
      _path -> true
    end
  end

  defp check_permissions(tool_def, permissions) do
    category = tool_def.category

    cond do
      # Dangerous tools are never allowed
      category == :dangerous ->
        {:error, :dangerous_tool_not_allowed}

      # Check if category permission is granted
      Map.get(permissions, category, false) == false ->
        # Check if specific permission is required
        case Map.get(tool_def, :requires_permission) do
          nil ->
            if Map.get(permissions, category, false) do
              :ok
            else
              {:error, {:permission_denied, category}}
            end

          required_perm ->
            if Map.get(permissions, required_perm, false) do
              :ok
            else
              {:error, {:permission_denied, required_perm}}
            end
        end

      true ->
        :ok
    end
  end

  defp do_execute_tool(tool_name, tool_def, args, opts) do
    command = build_command(tool_def.command, args, opts)
    timeout = Keyword.get(opts, :timeout, tool_def.timeout)

    Logger.debug("Executing tool: #{tool_name} - #{inspect(args)}")

    start_time = System.monotonic_time(:millisecond)

    try do
      {output, exit_code} = System.cmd(
        tool_def.command,
        args,
        stderr_to_stdout: true
      )

      duration = System.monotonic_time(:millisecond) - start_time

      result = %{
        output: String.trim(output),
        exit_code: exit_code,
        duration_ms: duration,
        success: exit_code == 0
      }

      {:ok, result}

    rescue
      e in [CaseClauseError] ->
        # This shouldn't happen with System.cmd
        duration = System.monotonic_time(:millisecond) - start_time
        {:error, %{error: "execution failed", duration_ms: duration}}

      e ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.error("Tool execution failed: #{inspect(e)}")
        {:error, %{error: inspect(e), duration_ms: duration}}
    end
  end

  defp build_command(base_command, args, opts) do
    # For logging purposes
    arg_str = Enum.join(args, " ")
    "#{base_command} #{arg_str}"
  end

  defp log_execution(tool_name, args, result) do
    status = case result do
      {:ok, %{success: true}} -> "SUCCESS"
      {:ok, %{success: false}} -> "FAILED"
      {:error, _} -> "ERROR"
    end

    Logger.info("Tool execution: #{tool_name} #{inspect(args)} -> #{status}")
  end
end

defmodule Padi.CLI.REPL do
  @moduledoc """
  Interactive Read-Eval-Print Loop for PADI CLI.

  Provides an interactive command-line interface where users can type
  natural language commands to interact with their projects.
  """

  use GenServer
  require Logger

  alias Padi.CLI.{ProjectDetector, NLPParser}

  @type state :: %{
    running: boolean(),
    project_info: map() | nil,
    history: [String.t()],
    current_dir: String.t()
  }

  # Client API

  @doc """
  Start the REPL server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stop the REPL server.
  """
  def stop do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Process a single command.
  """
  def process_command(command) do
    GenServer.call(__MODULE__, {:process_command, command})
  end

  @doc """
  Get current REPL state.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    current_dir = File.cwd!()
    project_info = ProjectDetector.get_project_info(current_dir)

    state = %{
      running: true,
      project_info: project_info,
      history: [],
      current_dir: current_dir
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:process_command, command}, _from, state) do
    new_state = %{state | history: [command | state.history]}

    result = do_process_command(command, new_state)

    case result do
      {:exit, _} ->
        {:reply, {:exit, "Goodbye!"}, %{new_state | running: false}}

      {:ok, response} ->
        {:reply, {:ok, response}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  # Private functions

  defp do_process_command(command, state) do
    parsed = NLPParser.parse(command)

    case parsed.intent do
      :exit ->
        {:exit, goodbye_message()}

      :help ->
        {:ok, NLPParser.get_help_text()}

      :status ->
        {:ok, format_status(state.project_info)}

      :unknown ->
        {:ok, format_unknown_command(command)}

      intent ->
        execute_intent(intent, parsed.args, state.project_info)
    end
  end

  defp execute_intent(intent, args, project_info) do
    project_type = project_info.type

    if project_type == :unknown do
      {:error, "No recognized project found. Please run padi from a project directory."}
    else
      command_atom = intent_to_command(intent)
      command = ProjectDetector.get_command(project_type, command_atom)

      if command == [] do
        {:error, "Command '#{intent}' is not supported for #{project_type} projects."}
      else
        execute_project_command(command, project_type, intent, args)
      end
    end
  end

  defp execute_project_command([tool | args], project_type, intent, user_args) do
    # Combine default args with user-provided args
    all_args = args ++ user_args

    IO.puts("\n🔄 Running: #{tool} #{Enum.join(all_args, " ")}")

    start_time = System.monotonic_time(:millisecond)

    case Padi.Tools.ToolRegistry.execute_tool(tool, all_args) do
      {:ok, result} ->
        duration = System.monotonic_time(:millisecond) - start_time

        if result.success do
          IO.puts("✅ Success (#{duration}ms)")
          IO.puts(format_output(result.output))

          {:ok, %{
            status: :success,
            output: result.output,
            duration_ms: duration,
            command: "#{tool} #{Enum.join(all_args, " ")}"
          }}
        else
          IO.puts("❌ Failed (exit code: #{result.exit_code}, #{duration}ms)")
          IO.puts(format_output(result.output))

          {:ok, %{
            status: :failed,
            output: result.output,
            exit_code: result.exit_code,
            duration_ms: duration,
            command: "#{tool} #{Enum.join(all_args, " ")}"
          }}
        end

      {:error, :tool_not_found} ->
        {:error, "Tool '#{tool}' not found. Please ensure it's installed on your system."}

      {:error, {:permission_denied, permission}} ->
        {:error, "Permission denied: #{permission} permission required."}

      {:error, reason} ->
        {:error, "Command failed: #{inspect(reason)}"}
    end
  end

  defp intent_to_command(:test), do: :test
  defp intent_to_command(:build), do: :build
  defp intent_to_command(:run), do: :run
  defp intent_to_command(:install), do: :install
  defp intent_to_command(:clean), do: :clean
  defp intent_to_command(:status), do: :status
  defp intent_to_command(:help), do: :help
  defp intent_to_command(:exit), do: :exit
  defp intent_to_command(_), do: :unknown

  defp format_status(project_info) do
    """
    📊 Project Status

    Project: #{project_info.name}
    Type: #{format_project_type(project_info.type)}
    Path: #{project_info.path}

    Supported Commands:
    #{format_supported_commands(project_info.supported_commands)}
    """
  end

  defp format_project_type(:elixir), do: "Elixir (mix)"
  defp format_project_type(:rust), do: "Rust (Cargo)"
  defp format_project_type(:nodejs), do: "Node.js (npm/yarn)"
  defp format_project_type(:python), do: "Python (pip/poetry)"
  defp format_project_type(:go), do: "Go (go mod)"
  defp format_project_type(:java), do: "Java (Maven/Gradle)"
  defp format_project_type(:unknown), do: "Unknown"

  defp format_supported_commands(commands) do
    commands
    |> Enum.map(fn cmd -> "  • #{cmd}" end)
    |> Enum.join("\n")
  end

  defp format_output(output) do
    if String.trim(output) == "" do
      "(no output)"
    else
      lines = String.split(output, "\n")
      # Limit output to prevent flooding
      limited_lines = Enum.take(lines, 50)

      formatted = Enum.join(limited_lines, "\n")
      if length(lines) > 50, do: formatted <> "\n... (output truncated)", else: formatted
    end
  end

  defp format_unknown_command(command) do
    """
    Unknown command: "#{command}"

    Type "help" to see available commands.
    """
  end

  defp goodbye_message do
    """
    👋 Thanks for using PADI!

    Your project is ready. Happy coding!
    """
  end
end

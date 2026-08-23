defmodule Padi.CLI.NLPParser do
  @moduledoc """
  Natural Language Parser for CLI commands.

  Parses user input in natural language and converts it to structured commands.
  Supports various phrasings and intents for common development operations.
  """

  @type intent :: :test | :build | :run | :install | :clean | :help | :status | :exit | :unknown
  @type parsed_command :: %{intent: intent(), args: [String.t()], raw: String.t()}

  # Intent patterns with regex and keyword matching
  @intent_patterns [
    # Test intent
    test: [
      ~r/(?:run|execute)?\s*(?:the\s*)?(?:unit\s*)?test(?:s)?/i,
      ~r/test\s+(?:the\s*)?(?:code|project|app)/i,
      ~r/run\s+test(?:ing)?/i,
      ~r/check\s+(?:if\s+)?tests?\s+pass/i,
      ~r/verify\s+tests?/i
    ],

    # Build intent
    build: [
      ~r/^(?:re)?build\b/i,
      ~r/(?:re)?build\s+(?:the\s*)?(?:code|project|app)/i,
      ~r/(?:re)?compile\s+(?:the\s*)?(?:code|project|app)/i,
      ~r/build\s+(?:the\s*)?project/i,
      ~r/make\s+(?:the\s*)?project/i
    ],

    # Run intent
    run: [
      ~r/run\s+(?:the\s*)?(?:code|project|app|program)/i,
      ~r/start\s+(?:the\s*)?(?:app|application|program)/i,
      ~r/execute\s+(?:the\s*)?(?:code|project|app)/i,
      ~r/(?:launch|boot)\s+(?:the\s*)?app/i
    ],

    # Install intent
    install: [
      ~r/(?:install\s+)?(?:dependencies|deps|packages?|modules?)/i,
      ~r/(?:install\s+)?(?:requirement|requirements)/i,
      ~r/get\s+deps/i,
      ~r/install\s+(?:the\s*)?dependencies/i,
      ~r/npm\s+install/i,
      ~r/bundle\s+install/i,
      ~r/pip\s+install/i,
      ~r/go\s+mod\s+download/i
    ],

    # Clean intent
    clean: [
      ~r/clean\s+(?:the\s*)?(?:project|build|cache|artifacts?)/i,
      ~r/clear\s+(?:the\s*)?(?:cache|build|artifacts?)/i,
      ~r/remove\s+(?:build\s+artifacts|artifacts?|build|cache)/i,
      ~r/(?:delete|remove)\s+node_modules/i
    ],

    # Help intent
    help: [
      ~r/(?:show\s+)?(?:help|usage|instructions|docs?)/i,
      ~r/what\s+can\s+(?:you|i)\s+do/i,
      ~r/how\s+(?:do\s+)?(?:i|to)\s+use/i,
      ~r/(?:commands?\s+available|available\s+commands)/i,
      ~r/list\s+commands?/i
    ],

    # Status intent
    status: [
      ~r/(?:show\s+)?(?:status|info|information)/i,
      ~r/how\s+(?:is\s+)?(?:the\s+)?project/i,
      ~r/(?:check|verify)\s+status/i,
      ~r/project\s+status/i,
      ~r/what\s+(?:is\s+)?(?:the\s+)?current/i
    ],

    # Exit intent
    exit: [
      ~r/(?:exit|quit|bye|goodbye)(?:\s+(?:now|please))?/i,
      ~r/(?:close|end)\s+(?:the\s+)?session/i,
      ~r/i'?m\s+done/i,
      ~r/that'?s\s+(?:all|enough)/i,
      ~r/stop\s+(?:the\s+)?(?:cli|app)/i
    ]
  ]

  @doc """
  Parse natural language input into a structured command.

  Returns a map with intent, arguments, and the original raw input.
  """
  @spec parse(String.t()) :: parsed_command()
  def parse(input) when is_binary(input) do
    trimmed = String.trim(input)

    cond do
      trimmed == "" ->
        %{intent: :unknown, args: [], raw: input}

      true ->
        intent = detect_intent(trimmed)
        args = extract_args(trimmed, intent)

        %{
          intent: intent,
          args: args,
          raw: input
        }
    end
  end

  @doc """
  Detect the intent from natural language input.
  """
  @spec detect_intent(String.t()) :: intent()
  def detect_intent(input) do
    input_lower = String.downcase(input)

    Enum.find_value(@intent_patterns, :unknown, fn {intent, patterns} ->
      Enum.find(patterns, fn pattern ->
        Regex.run(pattern, input) != nil
      end)
      |> case do
        nil -> nil
        _match -> intent
      end
    end)
  end

  @doc """
  Get help text for available commands.
  """
  @spec get_help_text() :: String.t()
  def get_help_text do
    """
    PADI CLI - Natural Language Commands

    Available commands (you can use natural language):

    Testing:
      • "run tests" / "run unit tests" / "test the code"
      • "check if tests pass" / "verify tests"

    Building:
      • "build the project" / "compile the code" / "rebuild"
      • "build the app" / "make the project"

    Running:
      • "run the app" / "start the application" / "execute the code"
      • "run the program" / "launch the app"

    Dependencies:
      • "install dependencies" / "install deps" / "get dependencies"
      • "npm install" / "bundle install" / "pip install"

    Cleaning:
      • "clean the project" / "clear the cache" / "clean build artifacts"
      • "remove node_modules" / "clear artifacts"

    Information:
      • "status" / "project status" / "show info"
      • "how is the project" / "what's the current status"

    Help:
      • "help" / "show help" / "what can I do"

    Exit:
      • "exit" / "quit" / "bye" / "I'm done"

    Project Support:
      • Elixir (mix.exs)
      • Rust (Cargo.toml)
      • Node.js (package.json)
      • Python (requirements.txt, setup.py)
      • Go (go.mod)
      • Java (pom.xml)

    Examples:
      • "run the tests" → runs project-specific tests
      • "build the project" → compiles the project
      • "install dependencies" → installs project dependencies
    """
  end

  @doc """
  Suggest commands based on partial input.
  """
  @spec suggest_commands(String.t()) :: [String.t()]
  def suggest_commands(input) do
    input_lower = String.downcase(input)

    suggestions =
      Enum.flat_map(@intent_patterns, fn {intent, _patterns} ->
        if String.contains?(input_lower, Atom.to_string(intent)) do
          [get_example_for_intent(intent)]
        else
          []
        end
      end)

    if suggestions == [], do: ["run tests", "build project", "install dependencies"], else: suggestions
  end

  # Private helpers

  defp extract_args(input, intent) do
    # Extract specific arguments from the input
    # For now, we'll use simple keyword extraction
    case intent do
      :test ->
        extract_test_args(input)

      :build ->
        extract_build_args(input)

      :run ->
        extract_run_args(input)

      _ ->
        []
    end
  end

  defp extract_test_args(input) do
    cond do
      Regex.run(~r/(?:test|spec)\s+([^\s]+)/i, input) != nil ->
        # Extract specific test file or pattern
        case Regex.run(~r/(?:test|spec)\s+([^\s]+)/i, input, capture: :all_but_first) do
          [arg | _] -> [arg]
          _ -> []
        end

      Regex.run(~r/--(?:watch|coverage|verbose)/i, input) != nil ->
        # Extract test flags
        Regex.scan(~r/--([\w-]+)/i, input)
        |> List.flatten()
        |> Enum.map(&"--#{&1}")

      true ->
        []
    end
  end

  defp extract_build_args(_input) do
    # Build typically doesn't need specific args
    []
  end

  defp extract_run_args(input) do
    cond do
      Regex.run(~r/run\s+([^\s]+)/i, input) != nil ->
        case Regex.run(~r/run\s+([^\s]+)/i, input, capture: :all_but_first) do
          [arg | _] when arg not in ["the", "a", "an"] -> [arg]
          _ -> []
        end

      true ->
        []
    end
  end

  defp get_example_for_intent(intent) do
    case intent do
      :test -> "run tests"
      :build -> "build project"
      :run -> "run the app"
      :install -> "install dependencies"
      :clean -> "clean the project"
      :help -> "help"
      :status -> "status"
      :exit -> "exit"
      :unknown -> "help"
    end
  end
end

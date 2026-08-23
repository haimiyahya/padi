defmodule Padi.CLI.NLPParser do
  @moduledoc """
  Natural Language Parser for CLI commands.

  Parses user input in natural language and converts it to structured commands.
  Supports various phrasings and intents for common development operations.
  """

  @type intent :: :test | :build | :run | :install | :clean | :help | :status | :exit | :add_feature | :fix_bug | :refactor | :query_codebase | :modify_code | :unknown
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
    ],

    # Code change intents - these require integration with codebase mutation system
    add_feature: [
      ~r/add\s+(?:a\s+)?(?:new\s+)?(?:function|feature|capability|method)/i,
      ~r/implement\s+(?:a\s+)?(?:new\s+)?(?:function|feature|capability)/i,
      ~r/create\s+(?:a\s+)?(?:new\s+)?(?:function|method)/i,
      ~r/add\s+(?:multiplication|division|addition|subtraction)/i,
      ~r/add\s+\w+\s+functionality/i,
      ~r/can\s+(?:you\s+)?(?:you\s+)?(?:add|create|implement)\s+/i,
      ~r/i\s+need\s+(?:a\s+)?\w+\s+function/i,
      ~r/\w+\s+(?:function|feature|capability)\s+(?:please|needed|required)/i
    ],

    fix_bug: [
      ~r/fix\s+(?:the\s+)?(?:bug|issue|problem|error)/i,
      ~r/repair\s+(?:the\s+)?(?:bug|issue)/i,
      ~r/(?:debug|resolve)\s+(?:the\s+)?(?:issue|problem)/i,
      ~r/there'?s\s+(?:a\s+)?bug\s+(?:in|with)\s+/i,
      ~r/something\s+(?:is\s+)?(?:broken|not\s+working)/i,
      ~r/error\s+(?:in|when|during)\s+/i
    ],

    refactor: [
      ~r/refactor\s+(?:the\s+)?(?:code|function|method|module)/i,
      ~r/restructure\s+(?:the\s+)?(?:code|architecture)/i,
      ~r/clean\s+up\s+(?:the\s+)?(?:code|implementation)/i,
      ~r/improve\s+(?:the\s+)?(?:code|structure|design)/i,
      ~r/optimize\s+(?:the\s+)?(?:code|performance)/i,
      ~r/simplify\s+(?:the\s+)?(?:code|logic)/i
    ],

    modify_code: [
      ~r/change\s+(?:the\s+)?(?:code|implementation|logic)/i,
      ~r/update\s+(?:the\s+)?(?:code|function|method)/i,
      ~r/modify\s+(?:the\s+)?(?:code|behavior|implementation)/i,
      ~r/alter\s+(?:the\s+)?(?:functionality|behavior)/i,
      ~r/rewrite\s+(?:the\s+)?(?:code|function|method)/i
    ],

    query_codebase: [
      ~r/what\s+(?:functions|capabilities|features)\s+(?:do\s+)?(?:we\s+)?(?:have|exist)/i,
      ~r/show\s+me\s+(?:what\s+)?(?:we\s+)?have/i,
      ~r/how\s+(?:does\s+)?(?:the\s+)?(?:code|project)\s+work/i,
      ~r/explain\s+(?:the\s+)?(?:code|system|architecture)/i,
      ~r/what\s+(?:can|does)\s+\w+\s+(?:do|contain)/i,
      ~r/tell\s+me\s+about\s+(?:the\s+)?(?:code|project)/i,
      ~r/do\s+(?:we\s+)?(?:have|support)\s+/i,
      ~r/is\s+there\s+(?:a\s+)?\w+\s+(?:function|method|feature)/i
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

    Code Generation (NEW):
      • "add multiplication functionality" → implements multiply function
      • "create a user authentication system" → generates auth code
      • "add error handling to the API" → adds error handling
      • "refactor the database layer" → restructures database code
      • "fix the login bug" → fixes issues
      • "what functions do we have?" → queries codebase capabilities

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
      • "add multiplication functionality" → implements multiply function
      • "what functions do we have?" → shows available functions
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
    case intent do
      :test ->
        extract_test_args(input)

      :build ->
        extract_build_args(input)

      :run ->
        extract_run_args(input)

      # For code change intents, extract the user request
      intent when intent in [:add_feature, :fix_bug, :refactor, :modify_code, :query_codebase] ->
        extract_code_change_request(input, intent)

      _ ->
        []
    end
  end

  defp extract_code_change_request(input, intent) do
    # Extract the user's request by removing the intent keywords
    intent_patterns = %{
      add_feature: [
        ~r/add\s+(?:a\s+)?(?:new\s+)?(?:function|feature|capability|method)\s+(?:of\s+|called\s+)?/i,
        ~r/implement\s+(?:a\s+)?(?:new\s+)?(?:function|feature|capability)\s+(?:of\s+|called\s+)?/i,
        ~r/create\s+(?:a\s+)?(?:new\s+)?(?:function|method)\s+(?:of\s+|called\s+)?/i,
        ~r/add\s+/i,
        ~r/can\s+(?:you\s+)?(?:you\s+)?(?:add|create|implement)\s+/i
      ],
      fix_bug: [
        ~r/fix\s+(?:the\s+)?(?:bug|issue|problem|error)\s+(?:in\s+)?/i,
        ~r/repair\s+(?:the\s+)?(?:bug|issue)\s+(?:in\s+)?/i,
        ~r/(?:debug|resolve)\s+(?:the\s+)?(?:issue|problem)\s+(?:in\s+)?/i
      ],
      refactor: [
        ~r/refactor\s+(?:the\s+)?/i,
        ~r/restructure\s+(?:the\s+)?/i,
        ~r/clean\s+up\s+(?:the\s+)?/i
      ],
      modify_code: [
        ~r/change\s+(?:the\s+)?/i,
        ~r/update\s+(?:the\s+)?/i,
        ~r/modify\s+(?:the\s+)?/i
      ],
      query_codebase: [
        ~r/what\s+(?:functions|capabilities|features)\s+(?:do\s+)?(?:we\s+)?(?:have|exist)\s+/i,
        ~r/show\s+me\s+(?:what\s+)?(?:we\s+)?have\s+/i,
        ~r/tell\s+me\s+about\s+(?:the\s+)?/i
      ]
    }

    patterns = Map.get(intent_patterns, intent, [])

    # Try to remove intent keywords and get the actual request
    request = Enum.reduce(patterns, input, fn pattern, acc ->
      String.replace(acc, pattern, "")
    end)

    # Clean up the request
    request = String.trim(request)

    # If request is empty, return the full input
    if request == "" do
      [input]
    else
      [request]
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

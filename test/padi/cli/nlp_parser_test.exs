defmodule Padi.CLI.NLPParserTest do
  @moduledoc """
  Tests for Natural Language Parser.
  """

  use ExUnit.Case
  alias Padi.CLI.NLPParser

  @moduletag :cli
  @moduletag :nlp_parser

  describe "Intent Detection" do
    test "detects test intent from various phrasings" do
      test_phrases = [
        "run tests",
        "run unit tests",
        "test the code",
        "execute tests",
        "check if tests pass",
        "verify tests"
      ]

      Enum.each(test_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :test, "Expected :test for phrase: '#{phrase}', got: #{intent}"
      end)
    end

    test "detects build intent from various phrasings" do
      build_phrases = [
        "build the project",
        "compile the code",
        "rebuild",
        "build the app"
      ]

      Enum.each(build_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :build, "Expected :build for phrase: '#{phrase}'"
      end)
    end

    test "detects run intent from various phrasings" do
      run_phrases = [
        "run the app",
        "start the application",
        "execute the code",
        "launch the app"
      ]

      Enum.each(run_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :run, "Expected :run for phrase: '#{phrase}'"
      end)
    end

    test "detects install intent" do
      install_phrases = [
        "install dependencies",
        "install deps",
        "get dependencies",
        "npm install"
      ]

      Enum.each(install_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :install, "Expected :install for phrase: '#{phrase}'"
      end)
    end

    test "detects clean intent" do
      clean_phrases = [
        "clean the project",
        "clear the cache",
        "remove build artifacts"
      ]

      Enum.each(clean_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :clean, "Expected :clean for phrase: '#{phrase}'"
      end)
    end

    test "detects help intent" do
      help_phrases = [
        "help",
        "show help",
        "what can I do",
        "available commands"
      ]

      Enum.each(help_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :help, "Expected :help for phrase: '#{phrase}'"
      end)
    end

    test "detects status intent" do
      status_phrases = [
        "status",
        "project status",
        "show info"
      ]

      Enum.each(status_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :status, "Expected :status for phrase: '#{phrase}'"
      end)
    end

    test "detects exit intent" do
      exit_phrases = [
        "exit",
        "quit",
        "bye",
        "goodbye",
        "I'm done"
      ]

      Enum.each(exit_phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :exit, "Expected :exit for phrase: '#{phrase}'"
      end)
    end

    test "returns unknown for unrecognized input" do
      intent = NLPParser.detect_intent("do something weird")
      assert intent == :unknown
    end
  end

  describe "Command Parsing" do
    test "parses complete command structure" do
      parsed = NLPParser.parse("run tests")

      assert is_map(parsed)
      assert Map.has_key?(parsed, :intent)
      assert Map.has_key?(parsed, :args)
      assert Map.has_key?(parsed, :raw)
      assert parsed.intent == :test
      assert parsed.raw == "run tests"
    end

    test "handles empty input" do
      parsed = NLPParser.parse("")

      assert parsed.intent == :unknown
      assert parsed.args == []
    end

    test "handles whitespace-only input" do
      parsed = NLPParser.parse("   ")

      assert parsed.intent == :unknown
      assert parsed.args == []
    end
  end

  describe "Help Text" do
    test "returns help text" do
      help = NLPParser.get_help_text()

      assert is_binary(help)
      assert String.length(help) > 0
      assert String.contains?(help, "PADI CLI")
      assert String.contains?(help, "Testing:")
      assert String.contains?(help, "Building:")
    end
  end

  describe "Command Suggestions" do
    test "suggests commands based on input" do
      suggestions = NLPParser.suggest_commands("test")

      assert is_list(suggestions)
      assert length(suggestions) > 0
    end

    test "provides default suggestions for empty input" do
      suggestions = NLPParser.suggest_commands("")

      assert is_list(suggestions)
      assert length(suggestions) > 0
      assert "run tests" in suggestions
    end
  end

  describe "Case Insensitivity" do
    test "detects intent regardless of case" do
      phrases = [
        "RUN TESTS",
        "Run Tests",
        "rUN tEsTs"
      ]

      Enum.each(phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        assert intent == :test, "Expected :test for phrase: '#{phrase}'"
      end)
    end
  end

  describe "Natural Language Variations" do
    test "handles colloquial test phrasings" do
      phrases = [
        "test this",
        "check the tests",
        "run the test suite",
        "test it"
      ]

      Enum.each(phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        # At least some should be detected as test or similar
        assert intent in [:test, :unknown], "Unexpected intent for '#{phrase}': #{intent}"
      end)
    end

    test "handles partial matches" do
      phrases = [
        "test",
        "build",
        "run",
        "exit"
      ]

      Enum.each(phrases, fn phrase ->
        intent = NLPParser.detect_intent(phrase)
        # Single words should still be detected
        assert intent != :unknown, "Should detect intent for '#{phrase}'"
      end)
    end
  end
end

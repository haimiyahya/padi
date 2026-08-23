defmodule Padi.Router.StdioHandlerTest do
  @moduledoc """
  Tests for the stdio handler that simulates actual CLI user interactions.

  These tests verify that the "steering wheel" (CLI interface) actually works
  by simulating stdin input and capturing stdout responses.

  Tests cover:
  - JSON-RPC request parsing from stdin
  - Response writing to stdout
  - Error handling and malformed input
  - Complete request/response cycles
  """

  use ExUnit.Case
  alias Padi.Router.{InterrogationRouter, StdioHandler}

  @moduletag :router
  @moduletag :stdio
  @moduletag :cli

  setup do
    Application.ensure_all_started(:padi)
    :ok
  end

  describe "JSON-RPC Request parsing" do
    test "parses valid JSON-RPC request from string" do
      # This simulates actual user input from CLI
      json_input = """
      {
        "jsonrpc": "2.0",
        "method": "codebase/get_status",
        "params": {"request_id": "test_123"},
        "id": "req_001"
      }
      """

      assert {:ok, request} = StdioHandler.parse_request(json_input)

      # The parsed request contains method, params, and id
      assert request.method == "codebase/get_status"
      assert is_map(request.params)
      assert request.id == "req_001"
    end

    test "parses request with string params" do
      json_input = ~s({
        "jsonrpc": "2.0",
        "method": "codebase/submit_mutation",
        "params": {
          "target_file": "lib/test.ex",
          "proposed_patch": "defmodule Test, do: :ok"
        },
        "id": "req_002"
      })

      assert {:ok, request} = StdioHandler.parse_request(json_input)

      assert request.method == "codebase/submit_mutation"
      assert request.params["target_file"] == "lib/test.ex"
      assert request.params["proposed_patch"] =~ ~r/defmodule/
    end

    test "parses request with array params" do
      json_input = ~s({
        "jsonrpc": "2.0",
        "method": "some/method",
        "params": ["param1", "param2"],
        "id": "req_003"
      })

      assert {:ok, request} = StdioHandler.parse_request(json_input)

      assert is_list(request.params)
      assert length(request.params) == 2
    end

    test "handles malformed JSON gracefully" do
      malformed_json = "{invalid json}"

      assert {:error, _reason} = StdioHandler.parse_request(malformed_json)
    end

    test "handles incomplete JSON object" do
      incomplete_json = '{"jsonrpc": "2.0", "method": "test"'

      assert {:error, _reason} = StdioHandler.parse_request(incomplete_json)
    end
  end

  describe "Response formatting and writing" do
    test "formats successful response correctly" do
      result = %{
        status: :success,
        message: "Operation completed"
      }

      json_response = StdioHandler.format_response("req_001", result)

      # Parse it back to verify structure
      assert {:ok, parsed} = Jason.decode(json_response)

      assert parsed["jsonrpc"] == "2.0"
      assert parsed["id"] == "req_001"
      assert Map.has_key?(parsed, "result")
      refute Map.has_key?(parsed, "error")
    end

    test "formats error response correctly" do
      error_response = StdioHandler.format_error(
        "req_002",
        -32600,  # Invalid Request
        "Invalid JSON-RPC request",
        %{"details" => "Missing required field"}
      )

      assert {:ok, parsed} = Jason.decode(error_response)

      assert parsed["jsonrpc"] == "2.0"
      assert parsed["id"] == "req_002"
      assert Map.has_key?(parsed, "error")

      error = parsed["error"]
      assert error["code"] == -32600
      assert error["message"] == "Invalid JSON-RPC request"
    end

    test "includes proper JSON-RPC error codes" do
      # Test standard JSON-RPC 2.0 error codes
      test_cases = [
        {-32700, "Parse error"},
        {-32600, "Invalid Request"},
        {-32601, "Method not found"},
        {-32602, "Invalid params"},
        {-32603, "Internal error"}
      ]

      Enum.each(test_cases, fn {code, message} ->
        error_json = StdioHandler.format_error("test_#{code}", code, message)

        assert {:ok, parsed} = Jason.decode(error_json)
        assert parsed["error"]["code"] == code
        assert parsed["error"]["message"] == message
      end)
    end
  end

  describe "Complete request/response cycle" do
    test "handles full get_status request cycle" do
      # Simulate complete user interaction
      json_request = ~s({
        "jsonrpc": "2.0",
        "method": "codebase/get_status",
        "params": {},
        "id": "cycle_001"
      })

      # Parse request
      assert {:ok, request} = StdioHandler.parse_request(json_request)

      # Process through router
      assert {:ok, router_response} = InterrogationRouter.handle_method(
        request.method,
        request.params,
        request.id
      )

      # Format response
      json_response = StdioHandler.format_response(request.id, router_response)

      # Verify response is valid JSON
      assert {:ok, parsed_response} = Jason.decode(json_response)

      assert parsed_response["jsonrpc"] == "2.0"
      assert parsed_response["id"] == "cycle_001"
      assert Map.has_key?(parsed_response, "result")
    end

    test "handles full submit_mutation request cycle" do
      json_request = ~s({
        "jsonrpc": "2.0",
        "method": "codebase/submit_mutation",
        "params": {
          "target_file": "lib/cli_test.ex",
          "proposed_patch": "defmodule CliTest, do: :ok"
        },
        "id": "cycle_002"
      })

      assert {:ok, request} = StdioHandler.parse_request(json_request)

      assert {:ok, router_response} = InterrogationRouter.handle_method(
        request.method,
        request.params,
        request.id
      )

      json_response = StdioHandler.format_response(request.id, router_response)

      assert {:ok, parsed_response} = Jason.decode(json_response)
      assert parsed_response["id"] == "cycle_002"
    end

    test "handles query_intent with natural language" do
      json_request = ~s({
        "jsonrpc": "2.0",
        "method": "codebase/query_intent",
        "params": {
          "intent_description": "Create a user authentication system"
        },
        "id": "cycle_003"
      })

      assert {:ok, request} = StdioHandler.parse_request(json_request)

      assert {:ok, router_response} = InterrogationRouter.handle_method(
        request.method,
        request.params,
        request.id
      )

      json_response = StdioHandler.format_response(request.id, router_response)

      assert {:ok, parsed_response} = Jason.decode(json_response)
      # Check that we have a valid result response
      assert Map.has_key?(parsed_response, "result")
      assert is_map(parsed_response["result"])
      # The result should contain status information
      assert Map.has_key?(parsed_response["result"], "status") or parsed_response["result"] != %{}
    end
  end

  describe "CLI workflow simulation" do
    test "simulates realistic user CLI session" do
      # This test simulates a real user typing commands in a CLI
      # It's the "steering wheel" test - does the interface actually work?

      # User command 1: Check system status
      cmd1 = ~s({"jsonrpc":"2.0","method":"codebase/get_status","params":{},"id":"1"})
      assert {:ok, req1} = StdioHandler.parse_request(cmd1)
      assert {:ok, resp1} = InterrogationRouter.handle_method(req1.method, req1.params, req1.id)
      json1 = StdioHandler.format_response(req1.id, resp1)
      assert {:ok, _} = Jason.decode(json1)

      # User command 2: Query for functionality
      cmd2 = ~s({"jsonrpc":"2.0","method":"codebase/query_intent","params":{"intent_description":"math functions"},"id":"2"})
      assert {:ok, req2} = StdioHandler.parse_request(cmd2)
      assert {:ok, resp2} = InterrogationRouter.handle_method(req2.method, req2.params, req2.id)
      json2 = StdioHandler.format_response(req2.id, resp2)
      assert {:ok, _} = Jason.decode(json2)

      # User command 3: Submit code changes
      cmd3 = Jason.encode!(%{
        "jsonrpc" => "2.0",
        "method" => "codebase/submit_mutation",
        "params" => %{
          "target_file" => "lib/math.ex",
          "proposed_patch" => "defmodule Math do\n  def add(a,b), do: a+b\nend"
        },
        "id" => "3"
      })
      assert {:ok, req3} = StdioHandler.parse_request(cmd3)
      assert {:ok, resp3} = InterrogationRouter.handle_method(req3.method, req3.params, req3.id)
      json3 = StdioHandler.format_response(req3.id, resp3)
      assert {:ok, parsed3} = Jason.decode(json3)

      # Verify the mutation was processed
      assert Map.has_key?(parsed3, "result")
      assert is_map(parsed3["result"])
    end

    test "handles user typing mistakes and malformed commands" do
      # Simulate common user errors when typing CLI commands

      # Missing closing brace
      malformed1 = ~s({"jsonrpc":"2.0","method":"test","id":"1")
      assert {:error, _} = StdioHandler.parse_request(malformed1)

      # Wrong JSON structure
      malformed2 = ~s({"method": "test", "id": "wrong"})
      assert {:error, _} = StdioHandler.parse_request(malformed2)

      # Extra commas
      malformed3 = ~s({"jsonrpc":"2.0",,"method":"test",,"id":"3"})
      assert {:error, _} = StdioHandler.parse_request(malformed3)
    end
  end

  describe "Real-world CLI scenarios" do
    test "handles multi-line code in JSON params" do
      # Real users will paste multi-line code
      multi_line_code = ~s'''
      defmodule Calculator do
        @doc """Performs addition"""
        def add(a, b) do
          a + b
        end

        @doc """Performs subtraction"""
        def subtract(a, b) do
          a - b
        end
      end
      '''

      json_request = """
      {
        "jsonrpc": "2.0",
        "method": "codebase/submit_mutation",
        "params": {
          "target_file": "lib/calc.ex",
          "proposed_patch": #{Jason.encode!(multi_line_code)}
        },
        "id": "multiline_001"
      }
      """

      assert {:ok, request} = StdioHandler.parse_request(json_request)

      # Verify the code was preserved properly
      assert request.params["proposed_patch"] =~ ~r/defmodule/
      assert request.params["proposed_patch"] =~ ~r/add\(a, b\)/
      assert request.params["proposed_patch"] =~ ~r/subtract\(a, b\)/
    end

    test "handles user interrupted input" do
      # Simulate user pressing Ctrl+C or interrupting input
      incomplete_input = ~s({"jsonrpc":"2.0","method":"codebase/)

      assert {:error, _} = StdioHandler.parse_request(incomplete_input)
    end

    test "handles different JSON formatting styles" do
      # Users might format JSON differently
      compact = ~s({"jsonrpc":"2.0","method":"test","params":{},"id":"1"})
      pretty = """
      {
        "jsonrpc": "2.0",
        "method": "test",
        "params": {},
        "id": "1"
      }
      """
      # With extra whitespace
      sparse = """
      {
        "jsonrpc"  :  "2.0"  ,
        "method"  :  "test"  ,
        "params"  :  {  }  ,
        "id"  :  "1"
      }
      """

      Enum.each([compact, pretty, sparse], fn json ->
        assert {:ok, _request} = StdioHandler.parse_request(json)
      end)
    end
  end

  describe "Performance and scalability" do
    test "handles rapid successive requests" do
      # Simulate a user or automated system making many rapid requests
      requests = for i <- 1..50 do
        ~s({
          "jsonrpc": "2.0",
          "method": "codebase/get_status",
          "params": {},
          "id": "#{i}"
        })
      end

      # Process all requests
      results = Enum.map(requests, fn json_req ->
        with {:ok, req} <- StdioHandler.parse_request(json_req),
             {:ok, resp} <- InterrogationRouter.handle_method(req.method, req.params, req.id),
             json_resp <- StdioHandler.format_response(req.id, resp),
             {:ok, parsed} <- Jason.decode(json_resp) do
          {:ok, parsed}
        else
          error -> error
        end
      end)

      # All requests should succeed
      successes = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      assert successes == 50
    end

    test "handles request with very long parameter values" do
      # Test with very long strings (e.g., large code files)
      long_code = String.duplicate("def f(), do: :ok\n", 1000)

      json_request = Jason.encode!(%{
        "jsonrpc" => "2.0",
        "method" => "codebase/submit_mutation",
        "params" => %{
          "target_file" => "lib/long.ex",
          "proposed_patch" => long_code
        },
        "id" => "long_001"
      })

      assert {:ok, request} = StdioHandler.parse_request(json_request)
      assert String.length(request.params["proposed_patch"]) > 0
    end
  end
end

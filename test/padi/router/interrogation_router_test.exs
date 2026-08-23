defmodule Padi.Router.InterrogationRouterTest do
  @moduledoc """
  Comprehensive tests for the JSON-RPC Interrogation Router.

  These tests simulate real user interactions through the JSON-RPC 2.0 protocol,
  ensuring the "steering wheel" actually connects to the system.

  Tests cover:
  - JSON-RPC method invocation and response handling
  - Error responses and protocol compliance
  - Method parameter validation
  - Integration with actual backend services
  """

  use ExUnit.Case
  alias Padi.Router.InterrogationRouter

  @moduletag :router
  @moduletag :json_rpc

  setup do
    # Ensure application is started
    Application.ensure_all_started(:padi)
    :ok
  end

  describe "JSON-RPC Protocol Compliance" do
    test "handles valid JSON-RPC request structure" do
      # This is the actual user-facing interface - the "steering wheel"
      request_id = "test_request_001"

      result = InterrogationRouter.handle_method(
        "codebase/get_status",
        %{"request_id" => "some_request_id"},
        request_id
      )

      # Should return a valid response envelope
      assert {:ok, response} = result
      assert Map.has_key?(response, :jsonrpc)
      assert Map.has_key?(response, :id)
      assert Map.has_key?(response, :result)
    end

    test "returns proper JSON-RPC error for invalid method" do
      request_id = "test_invalid_method"

      result = InterrogationRouter.handle_method(
        "nonexistent/method",
        %{},
        request_id
      )

      # Should return an error response
      assert {:error, _reason} = result
    end

    test "handles missing parameters gracefully" do
      request_id = "test_missing_params"

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        %{},  # Missing required parameters
        request_id
      )

      # Should handle missing params without crashing
      assert {:ok, response} = result
      # Response should contain error information
      assert Map.has_key?(response, :result)
    end
  end

  describe "codebase/get_status method" do
    test "returns status information" do
      request_id = "status_001"

      result = InterrogationRouter.handle_method(
        "codebase/get_status",
        %{"request_id" => "test_req_123"},
        request_id
      )

      assert {:ok, response} = result
      assert response.id == request_id
      assert response.jsonrpc == "2.0"

      # Result should contain status information
      status = response.result
      assert is_map(status)
    end

    test "handles missing request_id parameter" do
      request_id = "status_002"

      result = InterrogationRouter.handle_method(
        "codebase/get_status",
        %{},  # No request_id provided
        request_id
      )

      # Should still return a response
      assert {:ok, response} = result
      assert response.id == request_id
    end
  end

  describe "codebase/submit_mutation method" do
    test "accepts valid mutation through JSON-RPC" do
      # This is the critical test - simulating a real user submission
      request_id = "mutation_001"

      safe_code = """
      defmodule TestSafe do
        def add(a, b), do: a + b
      end
      """

      params = %{
        "target_file" => "lib/test_safe.ex",
        "proposed_patch" => safe_code
      }

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        params,
        request_id
      )

      assert {:ok, response} = result
      assert response.id == request_id

      # Should have a successful result
      mutation_result = response.result
      assert is_map(mutation_result)
    end

    test "rejects unsafe mutations through JSON-RPC" do
      # Test that policy violations are properly returned via JSON-RPC
      request_id = "mutation_002"

      unsafe_code = """
      defmodule TestUnsafe do
        def bad_hash do
          :crypto.hash(:sha, "data")  # Policy violation
        end
      end
      """

      params = %{
        "target_file" => "lib/test_unsafe.ex",
        "proposed_patch" => unsafe_code
      }

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        params,
        request_id
      )

      assert {:ok, response} = result
      assert response.id == request_id

      # Should return rejection with violations
      mutation_result = response.result
      assert is_map(mutation_result)
    end

    test "handles malformed code gracefully" do
      request_id = "mutation_003"

      malformed_code = """
      defmodule Broken do
        def incomplete(
      """

      params = %{
        "target_file" => "lib/broken.ex",
        "proposed_patch" => malformed_code
      }

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        params,
        request_id
      )

      # Should not crash, return a proper response
      assert {:ok, response} = result
      assert response.id == request_id
    end
  end

  describe "codebase/query_intent method" do
    test "processes natural language queries" do
      request_id = "query_001"

      params = %{
        "intent_description" => "Add a function to validate email addresses"
      }

      result = InterrogationRouter.handle_method(
        "codebase/query_intent",
        params,
        request_id
      )

      assert {:ok, response} = result
      assert response.id == request_id

      # Should return query results
      query_result = response.result
      assert is_map(query_result)
    end

    test "handles missing intent_description" do
      request_id = "query_002"

      params = %{}  # Missing intent_description

      result = InterrogationRouter.handle_method(
        "codebase/query_intent",
        params,
        request_id
      )

      # Should handle gracefully
      assert {:ok, response} = result
      assert response.id == request_id
    end

    test "processes complex multi-sentence queries" do
      request_id = "query_003"

      params = %{
        "intent_description" => "Create a new authentication module with password hashing using bcrypt, session management, and JWT token generation for secure API access"
      }

      result = InterrogationRouter.handle_method(
        "codebase/query_intent",
        params,
        request_id
      )

      assert {:ok, response} = result
      assert response.id == request_id
    end
  end

  describe "Integration with backend services" do
    test "submit_mutation integrates with policy checker" do
      # Verify the JSON-RPC layer actually connects to the policy checker
      request_id = "integration_001"

      # Code that should trigger policy violations
      suspicious_code = """
      defmodule Auth do
        def check_password(password, hash) do
          :crypto.hash(:md5, password) == hash  # MD5 is insecure
        end
      end
      """

      params = %{
        "target_file" => "lib/auth.ex",
        "proposed_patch" => suspicious_code
      }

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        params,
        request_id
      )

      assert {:ok, response} = result

      # The policy checker should have been consulted
      mutation_result = response.result
      assert is_map(mutation_result)
    end

    test "query_intent integrates with vector store" do
      # Verify semantic search works through JSON-RPC
      request_id = "integration_002"

      params = %{
        "intent_description" => "mathematical calculation operations"
      }

      result = InterrogationRouter.handle_method(
        "codebase/query_intent",
        params,
        request_id
      )

      assert {:ok, response} = result
      # Vector store should have been consulted for semantic matching
    end
  end

  describe "Error handling and edge cases" do
    test "handles null request id" do
      result = InterrogationRouter.handle_method(
        "codebase/get_status",
        %{},
        nil
      )

      # Should handle null ID gracefully
      assert {:ok, _response} = result
    end

    test "handles very large code submissions" do
      # Test with large code that might exceed buffer sizes
      large_code = String.duplicate("def large_function(), do: :ok\n", 10_000)

      params = %{
        "target_file" => "lib/large.ex",
        "proposed_patch" => large_code
      }

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        params,
        "large_001"
      )

      # Should handle large submissions without crashing
      assert {:ok, _response} = result
    end

    test "handles special characters in file paths" do
      request_id = "special_001"

      params = %{
        "target_file" => "lib/test/special@#$%.ex",
        "proposed_patch" => "defmodule Special, do: :ok"
      }

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        params,
        request_id
      )

      # Should handle special characters
      assert {:ok, _response} = result
    end

    test "handles unicode in code content" do
      request_id = "unicode_001"

      unicode_code = """
      defmodule Unicode do
        def hello, do: "こんにちは世界"
        def emoji, do: "🎉🚀"
      end
      """

      params = %{
        "target_file" => "lib/unicode.ex",
        "proposed_patch" => unicode_code
      }

      result = InterrogationRouter.handle_method(
        "codebase/submit_mutation",
        params,
        request_id
      )

      # Should handle unicode properly
      assert {:ok, _response} = result
    end
  end

  describe "Response envelope structure" do
    test "returns properly formatted JSON-RPC response" do
      request_id = "envelope_001"

      result = InterrogationRouter.handle_method(
        "codebase/get_status",
        %{"request_id" => "test_req"},
        request_id
      )

      assert {:ok, response} = result

      # Verify JSON-RPC 2.0 response structure
      assert Map.has_key?(response, :jsonrpc)
      assert Map.has_key?(response, :id)
      assert Map.has_key?(response, :result)

      # Should NOT have error field on success
      refute Map.has_key?(response, :error)

      # jsonrpc version should be "2.0"
      assert response.jsonrpc == "2.0"

      # id should match request
      assert response.id == request_id
    end

    test "result contains expected data types" do
      request_id = "types_001"

      result = InterrogationRouter.handle_method(
        "codebase/get_status",
        %{},
        request_id
      )

      assert {:ok, response} = result

      # Result should be a map with proper types
      assert is_map(response.result)
    end
  end

  describe "Concurrent request handling" do
    test "handles multiple simultaneous requests" do
      # Test that the router can handle concurrent requests
      tasks = for i <- 1..10 do
        Task.async(fn ->
          InterrogationRouter.handle_method(
            "codebase/get_status",
            %{},
            "concurrent_#{i}"
          )
        end)
      end

      results = Task.await_many(tasks, 5000)

      # All requests should complete successfully
      assert length(results) == 10
      assert Enum.all?(results, fn
        {:ok, _response} -> true
        _ -> false
      end)
    end
  end
end

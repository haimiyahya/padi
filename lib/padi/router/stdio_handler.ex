defmodule Padi.Router.StdioHandler do
  @moduledoc """
  JSON-RPC 2.0 handler over stdin/stdout.

  This module provides a simple stdin/stdout transport for JSON-RPC messages,
  making it easy to integrate Padi with various tools and agents.

  Usage:
  1. Agent writes JSON-RPC request to stdout
  2. Padi processes the request
  3. Padi writes JSON-RPC response to stdin

  This is the simplest transport option and works with most tools.
  """

  use GenServer
  require Logger

  @doc """
  Start the stdio handler.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Read a JSON-RPC request from stdin.
  """
  def read_request do
    GenServer.call(__MODULE__, :read_request)
  end

  @doc """
  Write a JSON-RPC response to stdout.
  """
  def write_response(data) when is_map(data) do
    GenServer.cast(__MODULE__, {:write_response, data})
  end

  @doc """
  Write an error response.
  """
  def write_error(id, code, message, data \\ nil) do
    error = Padi.Protocol.Messages.error_envelope(id, code, message, data)
    write_response(error)
  end

  @doc """
  Enter the main request/response loop.
  """
  def serve do
    GenServer.call(__MODULE__, :serve)
  end

  @doc """
  Parse a JSON-RPC request string into a request struct.
  """
  def parse_request(json_string) when is_binary(json_string) do
    try do
      with {:ok, data} <- Jason.decode(json_string),
           {:ok, request} <- Padi.Protocol.Messages.parse_request(data) do
        {:ok, request}
      else
        {:error, _} = error -> {:error, error}
        error -> {:error, error}
      end
    rescue
      _ -> {:error, :parse_error}
    end
  end

  @doc """
  Format a response map into a JSON-RPC response string.
  """
  def format_response(id, result) when is_map(result) do
    response = Padi.Protocol.Messages.response_envelope(id, result)
    Jason.encode!(response)
  end

  @doc """
  Format an error into a JSON-RPC error response string.
  """
  def format_error(id, code, message, data \\ nil) do
    error = Padi.Protocol.Messages.error_envelope(id, code, message, data)
    Jason.encode!(error)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.debug("StdioHandler initialized")
    {:ok, %{}}
  end

  @impl true
  def handle_call(:read_request, _from, state) do
    case IO.read(:stdio, :line) do
      {:ok, line} ->
        case Jason.decode(line) do
          {:ok, data} ->
            case Padi.Protocol.Messages.parse_request(data) do
              {:ok, request} ->
                {:reply, {:ok, request}, state}

              {:error, reason} ->
                {:reply, {:error, reason}, state}
            end

          {:error, _} ->
            {:reply, {:error, :parse_error}, state}
        end

      :eof ->
        {:reply, :eof, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:serve, _from, state) do
    # Enter the main loop
    Task.start(fn -> serve_loop() end)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:write_response, data}, state) do
    json = Jason.encode!(data)
    IO.puts(json)
    {:noreply, state}
  end

  # Private: Main serve loop

  defp serve_loop do
    case read_line() do
      {:ok, line} ->
        case process_line(line) do
          :continue -> serve_loop()
          :stop -> :ok
        end

      :eof ->
        Logger.info("StdioHandler received EOF, stopping")
        :ok

      {:error, reason} ->
        Logger.error("StdioHandler error: #{inspect(reason)}")
        :ok
    end
  end

  defp read_line do
    case IO.read(:stdio, :line) do
      {:ok, line} -> {:ok, String.trim(line)}
      :eof -> :eof
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_line(line) do
    Logger.debug("Received request: #{String.slice(line, 0, 100)}...")

    case Jason.decode(line) do
      {:ok, data} ->
        case Padi.Protocol.Messages.parse_request(data) do
          {:ok, %{id: id, method: method, params: params}} ->
            # Dispatch to the InterrogationRouter
            case Padi.Router.InterrogationRouter.handle_method(method, params, id) do
              {:ok, response} ->
                write_response(response)
                :continue

              {:error, _reason} ->
                write_error(id, -32603, "Internal error")
                :continue
            end

          {:error, reason} ->
            # Parse error - we don't have an id
            write_error(nil, -32700, "Parse error: #{inspect(reason)}")
            :continue
        end

      {:error, _reason} ->
        write_error(nil, -32700, "Parse error")
        :continue
    end
  end
end

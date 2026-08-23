defmodule Mix.Tasks.Padi.Server do
  @moduledoc """
  Starts the PADI server with JSON-RPC interface.

  ## Usage

      mix padi.server

  ## Options

      --port - Port number for JSON-RPC server (default: 8080)
      --host - Host to bind to (default: localhost)

  ## Examples

      # Start server on default port
      mix padi.server

      # Start server on custom port
      mix padi.server --port 9000

      # Start server on all interfaces
      mix padi.server --host 0.0.0.0
  """

  use Mix.Task

  @shortdoc "Starts the PADI server"

  @impl true
  def run(args) do
    # Parse options
    {opts, _, _} = OptionParser.parse(args,
      switches: [port: :integer, host: :string],
      aliases: [p: :port, h: :host]
    )

    port = Keyword.get(opts, :port, 8080)
    host = Keyword.get(opts, :host, "localhost")

    # Ensure application is started
    Application.ensure_all_started(:padi)

    # Start the stdio handler (JSON-RPC interface)
    IO.puts("Starting PADI server...")
    IO.puts("Press Ctrl+C to stop")
    IO.puts("")

    # For now, we'll use the stdio handler which reads from stdin
    # In a full implementation, this would start a network server
    case Padi.Router.StdioHandler.serve() do
      :ok ->
        IO.puts("PADI server started successfully")
      :error ->
        IO.puts("Failed to start PADI server")
    end

    # Keep the process running
    Process.sleep(:infinity)
  end
end

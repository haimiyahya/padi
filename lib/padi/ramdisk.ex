defmodule Padi.Ramdisk do
  @moduledoc """
  Ramdisk initialization and management.

  Creates and manages the tmpfs workspace used for fast file operations.
  Target I/O latency: <500μs
  """

  @ramdisk_path Application.compile_env(:padi, :ramdisk)[:path] || "/tmp/padi_ramdisk"

  @doc """
  Setup the ramdisk directory structure.
  """
  def setup do
    create_directory(@ramdisk_path)
    create_workspace()
    :ok
  end

  @doc """
  Get the ramdisk path.
  """
  def path, do: @ramdisk_path

  @doc """
  Get the workspace path within ramdisk.
  """
  def workspace_path, do: Path.join(@ramdisk_path, "workspace")

  @doc """
  Check if ramdisk is properly mounted.
  """
  def ready? do
    File.dir?(@ramdisk_path)
  end

  # Private helpers

  defp create_directory(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, reason} -> raise "Failed to create ramdisk: #{inspect(reason)}"
    end
  end

  defp create_workspace do
    workspace = workspace_path()
    create_directory(workspace)
    create_directory(Path.join(workspace, "repo"))
    create_directory(Path.join(workspace, "sandbox"))
    :ok
  end
end

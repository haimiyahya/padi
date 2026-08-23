defmodule Padi do
  @moduledoc """
  Padi - Cybernetic BEAM Harness ("Code That Can Talk")

  An active, self-describing, self-defending control plane for autonomous
  software engineering agents.
  """

  @doc """
  Get the current application version.
  """
  def version, do: "0.1.0"

  @doc """
  Get the ramdisk path.
  """
  def ramdisk_path do
    Application.get_env(:padi, :ramdisk)[:path] || "/tmp/padi_ramdisk"
  end
end

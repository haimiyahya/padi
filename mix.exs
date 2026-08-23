defmodule Padi.MixProject do
  use Mix.Project

  def project do
    [
      app: :padi,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      rustler_crates: rustler_crates(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Padi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.38"},
      {:rustler_precompiled, "~> 0.9"},
      {:jason, "~> 1.4"},
      {:ecto, "~> 3.11"}
    ]
  end

  # Rust NIF crates
  defp rustler_crates do
    [
      ladypadi: [mode: if(Mix.env() == :prod, do: :release, else: :debug)],
      treepadi: [mode: if(Mix.env() == :prod, do: :release, else: :debug)],
      vectorpadi: [mode: if(Mix.env() == :prod, do: :release, else: :debug)]
    ]
  end
end

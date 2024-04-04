defmodule Air2Cast.MixProject do
  use Mix.Project

  def project do
    [
      app: :air2_cast,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:mdns, "~> 1.0"},
      {:exprotobuf, "~> 1.2"},
      {:poison, "~> 2.2.0"},
      # {:rambo, "~> 0.3.4"},
      {:mime, "~> 2.0"},
      {:exile, "~> 0.9.1"},
      {:plug, "~> 1.15"}
      # {:chromecast, "~> 0.1.5"},
      # {:ffmpex, "~> 0.10.0"}
    ]
  end
end

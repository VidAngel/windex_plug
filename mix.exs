defmodule WindexPlug.MixProject do
  use Mix.Project

  def project do
    [
      app: :windex_plug,
      version: "1.2.0",
      elixir: "~> 1.10",
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
      {:windex, git: "git@github.com:VidAngel/windex.git", tag: "0.3.1"},
      {:plug, "~> 1.10.3"},
      {:jason, "~> 1.2.1"},
    ]
  end
end

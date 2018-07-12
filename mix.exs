defmodule XMediaLib.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :xmedialib,
      version: "0.1.0",
      elixir: "~> 1.0",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      deps: deps()
    ]
  end

  def application() do
    [applications: [:logger]]
  end

  defp deps() do
    []
  end
end

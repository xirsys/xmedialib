defmodule XMediaLib.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :xmedialib,
      version: "0.1.0",
      elixir: "~> 1.0",
      compilers: [:elixir_make] ++ Mix.compilers,
      package: package(),
      deps_path: "deps",
      lockfile: "mix.lock",
      deps: deps()
    ]
  end

  def application() do
    [applications: [:logger]]
  end

  defp deps() do
    [
      {:elixir_make, "~> 0.4", runtime: false},
      {:skerl, git: "https://github.com/xirsys/skerl.git"}
    ]
  end

  defp package do
    [
      files: ["lib", "c_src", "mix.exs", "Makefile*", "README.md"],
      maintainers: ["Lee Sylvester"],
      licenses: ["Apache2"],
      links: %{"GitHub" => "https://github.com/xirsys/xmedialib"}
    ]
  end
end

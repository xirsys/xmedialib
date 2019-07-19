defmodule XMediaLib.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :xmedialib,
      version: "0.1.0",
      elixir: "~> 1.6.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Media library for the XTurn server.",
      source_url: "https://github.com/xirsys/xmedialib",
      homepage_url: "https://xturn.me",
      package: package(),
      docs: [
        extras: ["README.md", "LICENCE"],
        main: "readme"
      ]
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
    %{
      files: ["lib", "c_src", "mix.exs", "Makefile*", "README.md", "LICENSE"],
      maintainers: ["Jahred Love"],
      licenses: ["Apache 2.0"],
      organization: ["Xirsys"],
      links: %{"Github" => "https://github.com/xirsys/xmedialib"}
    }
  end
end

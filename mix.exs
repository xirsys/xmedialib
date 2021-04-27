defmodule XMediaLib.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :xmedialib,
      version: "0.1.3",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Media library for the XTurn server.",
      source_url: "https://github.com/xirsys/xmedialib",
      homepage_url: "https://xturn.me",
      package: package(),
      docs: [
        extras: ["README.md", "LICENSE.md", "CHANGELOG.md"],
        main: "readme"
      ]
    ]
  end

  def application() do
    [
      applications: [:logger],
      extra_applications: [:crypto]
    ]
  end

  defp deps() do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:elixir_make, "~> 0.6.2", runtime: false},
      {:skex, "~> 0.1.2"}
    ]
  end

  defp package do
    %{
      files: [
        "lib",
        "c_src",
        "mix.exs",
        "priv",
        "Makefile*",
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md"
      ],
      maintainers: ["Jahred Love"],
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/xirsys/xmedialib"}
    }
  end
end

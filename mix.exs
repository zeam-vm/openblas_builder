defmodule OpenblasBuilder.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/zeam-vm/openblas_builder"

  def project do
    [
      app: :openblas_builder,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "readme",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: ["README.md"]
      ],
      package: [
        licenses: ["Apache-2.0"],
        links: %{
          "GitHub" => @source_url
        },
        files: [
          "lib",
          "mix.exs",
          "README.md",
          "LICENSE",
          "CHANGELOG.md"
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:flow, "~> 1.2"}
    ]
  end
end

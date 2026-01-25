defmodule Casbin.MixProject do
  use Mix.Project

  def project do
    [
      app: :casbin,
      version: "1.6.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/casbin/casbin-ex",
      homepage_url: "https://casbin.org"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Casbin, []}
    ]
  end

  def elixirc_paths(:test), do: ["lib", "test/support"]
  def elixirc_paths(_), do: ["lib"]

  defp deps do
    # No external dependencies for this minimal test build
    []
  end

  defp description() do
    "Casbin-Ex is a powerful and efficient open-source access control library for Elixir projects."
  end

  defp package() do
    [
      name: "casbin",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/casbin/casbin-ex",
        "Homepage" => "https://casbin.org",
        "Docs" => "https://casbin.org/docs/overview"
      }
    ]
  end
end

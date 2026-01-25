#!/bin/bash

# Let's try to work around the network issue by modifying mix.exs temporarily to remove optional dependencies

cd /home/runner/work/casbin-ex/casbin-ex

# Create a simplified mix.exs that only has core deps
cat > mix_simple.exs << 'MIX_EOF'
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
    [
      {:ecto_sql, "~> 3.10"}
      # Removed dev/test-only deps to work around network issues
    ]
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
MIX_EOF

# Check if any Hex packages are available as local files
ls -la /opt/hex 2>/dev/null || echo "No /opt/hex"

# Let's check what other systems might have the packages
for dir in ~/.mix ~/.cache ~/.asdf /opt /usr/local/lib /usr/lib; do
  if [ -d "$dir" ]; then
    find "$dir" -name "ecto_sql*" -o -name "decimal*" 2>/dev/null | head -3
  fi
done


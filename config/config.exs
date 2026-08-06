import Config

if Mix.env() == :dev do
  config :git_hooks,
    # Pin the project root, otherwise auto_install bakes deps/git_hooks into
    # the generated hook and it runs mix from the dependency's own directory.
    project_path: File.cwd!(),
    auto_install: true,
    verbose: true,
    hooks: [
      pre_push: [
        tasks: [
          {:cmd, "mix credo --strict"},
          {:cmd, "mix format"}
        ]
      ]
    ]
end

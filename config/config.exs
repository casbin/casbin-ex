import Config

if Mix.env() == :dev do
  config :git_hooks,
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

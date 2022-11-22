defmodule Acx do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Acx.EnforcerRegistry},
      Acx.EnforcerSupervisor
    ]

    :ets.new(:enforcers_table, [:public, :named_table])

    opts = [strategy: :one_for_one, name: Acx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule Casbin do
  @moduledoc """
  Casbin is an Elixir implementation of the Casbin authorization library.
  """
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Casbin.EnforcerRegistry},
      Casbin.EnforcerSupervisor
    ]

    :ets.new(:enforcers_table, [:public, :named_table])

    opts = [strategy: :one_for_one, name: Casbin.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

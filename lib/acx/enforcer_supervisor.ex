defmodule Acx.EnforcerSupervisor do
  @moduledoc """
  A supervisor that starts `Enforcer` processes dynamically.
  """

  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new `Enforcer` process and supervises it
  """
  def start_enforcer(ename, cfile) do
    child_spec = %{
      id: Acx.EnforcerServer,
      start: {Acx.EnforcerServer, :start_link, [ename, cfile]},
      restart: :permanent
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end

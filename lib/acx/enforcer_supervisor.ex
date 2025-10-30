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

  @doc """
  Starts a new isolated `Enforcer` process and supervises it.

  Unlike `start_enforcer/2`, this creates a fresh enforcer instance without
  using the global ETS table for caching. This is useful for async tests.
  """
  def start_enforcer_isolated(ename, cfile) do
    child_spec = %{
      id: Acx.EnforcerServer,
      start: {Acx.EnforcerServer, :start_link_isolated, [ename, cfile]},
      restart: :permanent
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end

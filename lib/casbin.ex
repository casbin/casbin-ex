defmodule Casbin do
  @moduledoc """
  Casbin is an Elixir implementation of the Casbin authorization library.

  Casbin provides authorization support based on various access control models
  including ACL, RBAC, ABAC, and RESTful models.

  ## Usage

  There are two ways to use Casbin:

  ### 1. Using EnforcerServer (Recommended for Production)

  For production applications, use `Casbin.EnforcerServer` which manages
  enforcer state in a supervised GenServer process:

      # Start an enforcer
      Casbin.EnforcerSupervisor.start_enforcer("my_enforcer", "config.conf")
      
      # Add policies
      Casbin.EnforcerServer.add_policy("my_enforcer", {:p, ["alice", "data", "read"]})
      
      # Check permissions
      Casbin.EnforcerServer.allow?("my_enforcer", ["alice", "data", "read"])

  ### 2. Using Enforcer Struct Directly

  For simple use cases or testing, use the `Casbin.Enforcer` module directly:

      {:ok, enforcer} = Casbin.Enforcer.init("config.conf")
      {:ok, enforcer} = Casbin.Enforcer.add_policy(enforcer, {:p, ["alice", "data", "read"]})
      Casbin.Enforcer.allow?(enforcer, ["alice", "data", "read"])

  ## Testing

  For async testing with isolated enforcer instances, use `Casbin.TestHelper`:

      defmodule MyTest do
        use ExUnit.Case, async: true
        import Casbin.TestHelper
        
        setup do
          name = unique_enforcer_name()
          {:ok, _} = start_test_enforcer(name, "config.conf")
          on_exit(fn -> cleanup_test_enforcer(name) end)
          {:ok, enforcer_name: name}
        end
      end

  See the `Casbin.TestHelper` module and `guides/async_testing.md` for more details.
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

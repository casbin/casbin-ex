defmodule Casbin.TestHelper do
  @moduledoc """
  Helper functions for testing with Casbin enforcers in async test environments.

  This module provides utilities to create isolated enforcer instances per test,
  enabling `async: true` tests that don't share global state.

  ## Example

      defmodule MyApp.AclTest do
        use ExUnit.Case, async: true
        import Casbin.TestHelper

        setup do
          # Create a unique enforcer for this test
          enforcer_name = unique_enforcer_name()
          cfile = "path/to/config.conf"
          
          {:ok, _pid} = start_test_enforcer(enforcer_name, cfile)
          
          # Automatically clean up after the test
          on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)
          
          {:ok, enforcer_name: enforcer_name}
        end

        test "my test", %{enforcer_name: name} do
          Casbin.EnforcerServer.add_policy(name, {:p, ["alice", "data", "read"]})
          assert Casbin.EnforcerServer.allow?(name, ["alice", "data", "read"])
        end
      end

  ## Using with Ecto Adapters

  When using with `Ecto.Adapters.SQL.Sandbox`, you may need to use shared mode:

      setup do
        enforcer_name = unique_enforcer_name()
        cfile = "path/to/config.conf"
        
        # Set up sandbox
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
        Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
        
        # Start enforcer
        {:ok, pid} = start_test_enforcer(enforcer_name, cfile)
        
        # Allow enforcer to access the database connection
        Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, self(), pid)
        
        on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)
        
        {:ok, enforcer_name: enforcer_name}
      end
  """

  alias Casbin.EnforcerSupervisor
  alias Casbin.EnforcerServer

  @doc """
  Generates a unique enforcer name for isolated testing.

  Returns a string in the format "test_enforcer_<ref>_<timestamp>_<random>"
  where ref is the test process reference.

  ## Examples

      iex> name1 = Casbin.TestHelper.unique_enforcer_name()
      iex> name2 = Casbin.TestHelper.unique_enforcer_name()
      iex> name1 != name2
      true

      iex> Casbin.TestHelper.unique_enforcer_name("my_test")
      "test_enforcer_my_test_" <> _
  """
  @spec unique_enforcer_name(String.t()) :: String.t()
  def unique_enforcer_name(prefix \\ "") do
    ref = :erlang.ref_to_list(make_ref()) |> to_string() |> String.replace(~r/[^0-9]/, "")
    timestamp = System.system_time(:microsecond)
    random = :rand.uniform(999_999)

    prefix_part = if prefix != "", do: "#{prefix}_", else: ""
    "test_enforcer_#{prefix_part}#{ref}_#{timestamp}_#{random}"
  end

  @doc """
  Starts an enforcer process for testing with the given name and configuration file.

  This is a wrapper around `Casbin.EnforcerSupervisor.start_enforcer/2` that
  returns the PID for convenience in test setup.

  ## Parameters

    * `enforcer_name` - Unique name for the enforcer (use `unique_enforcer_name/0`)
    * `config_file` - Path to the Casbin model configuration file

  ## Returns

    * `{:ok, pid}` - The PID of the started enforcer server
    * `{:error, reason}` - If the enforcer could not be started

  ## Examples

      {:ok, pid} = start_test_enforcer("my_test_enforcer", "test/data/model.conf")
  """
  @spec start_test_enforcer(String.t(), String.t()) ::
          {:ok, pid()} | {:error, term()}
  def start_test_enforcer(enforcer_name, config_file) do
    EnforcerSupervisor.start_enforcer(enforcer_name, config_file)
  end

  @doc """
  Cleans up a test enforcer by stopping its process and removing it from the ETS table.

  This should be called in an `on_exit/1` callback to ensure proper cleanup.

  ## Parameters

    * `enforcer_name` - The name of the enforcer to clean up

  ## Examples

      on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)
  """
  @spec cleanup_test_enforcer(String.t()) :: :ok
  def cleanup_test_enforcer(enforcer_name) do
    # Stop the enforcer process if it exists
    case Registry.lookup(Casbin.EnforcerRegistry, enforcer_name) do
      [{pid, _}] ->
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(EnforcerSupervisor, pid)
        end

      [] ->
        :ok
    end

    # Remove from ETS table
    :ets.delete(:enforcers_table, enforcer_name)

    :ok
  end

  @doc """
  Resets an enforcer to its initial state by reloading the configuration.

  Useful when you need to clear all policies between test cases without
  creating a new enforcer instance.

  ## Parameters

    * `enforcer_name` - The name of the enforcer to reset
    * `config_file` - Path to the configuration file to reload

  ## Examples

      reset_test_enforcer(enforcer_name, "test/data/model.conf")
  """
  @spec reset_test_enforcer(String.t(), String.t()) :: :ok | {:error, term()}
  def reset_test_enforcer(enforcer_name, config_file) do
    EnforcerServer.reset_configuration(enforcer_name, config_file)
  end
end

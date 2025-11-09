defmodule Acx.TestHelper do
  @moduledoc """
  Test utilities for working with Casbin enforcers in async tests.

  This module provides helpers to create isolated enforcer instances for each test,
  enabling `async: true` tests that don't interfere with each other.

  ## Usage

  In your test file:

      defmodule MyApp.CasbinTest do
        use ExUnit.Case, async: true
        import Acx.TestHelper

        setup do
          # Creates a unique enforcer for this test
          ename = unique_enforcer_name()
          cfile = "path/to/config.conf"
          
          Acx.EnforcerSupervisor.start_enforcer(ename, cfile)
          
          # Automatically cleanup on test exit
          on_exit(fn -> cleanup_enforcer(ename) end)
          
          {:ok, enforcer_name: ename}
        end

        test "some test", %{enforcer_name: ename} do
          Acx.EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
          assert Acx.EnforcerServer.allow?(ename, ["alice", "data", "read"])
        end
      end

  ## Alternative: Using setup_enforcer/1

  For simpler setup, you can use the `setup_enforcer/1` function:

      defmodule MyApp.CasbinTest do
        use ExUnit.Case, async: true
        import Acx.TestHelper

        setup do
          setup_enforcer("path/to/config.conf")
        end

        test "some test", %{enforcer_name: ename} do
          Acx.EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
          assert Acx.EnforcerServer.allow?(ename, ["alice", "data", "read"])
        end
      end
  """

  @doc """
  Generates a unique enforcer name for the current test.

  The name is based on the test's process ID and a timestamp, ensuring
  that each test gets its own isolated enforcer instance.

  ## Examples

      iex> ename = Acx.TestHelper.unique_enforcer_name()
      iex> is_binary(ename)
      true
  """
  @spec unique_enforcer_name() :: String.t()
  def unique_enforcer_name do
    "test_enforcer_#{:erlang.unique_integer([:positive])}"
  end

  @doc """
  Generates a unique enforcer name with a custom prefix.

  ## Examples

      iex> ename = Acx.TestHelper.unique_enforcer_name("my_test")
      iex> String.starts_with?(ename, "my_test_")
      true
  """
  @spec unique_enforcer_name(String.t()) :: String.t()
  def unique_enforcer_name(prefix) when is_binary(prefix) do
    "#{prefix}_#{:erlang.unique_integer([:positive])}"
  end

  @doc """
  Cleans up an enforcer instance and removes it from the registry.

  This function should be called in an `on_exit` callback to ensure
  proper cleanup after each test.

  ## Examples

      on_exit(fn -> cleanup_enforcer(ename) end)
  """
  @spec cleanup_enforcer(String.t()) :: :ok
  def cleanup_enforcer(ename) when is_binary(ename) do
    # Try to stop the enforcer process if it exists
    case Registry.lookup(Acx.EnforcerRegistry, ename) do
      [{pid, _}] ->
        # Stop the GenServer gracefully
        if Process.alive?(pid) do
          GenServer.stop(pid, :normal)
        end

      [] ->
        :ok
    end

    # Clean up the ETS table entry
    :ets.delete(:enforcers_table, ename)

    :ok
  end

  @doc """
  Sets up a unique enforcer for the current test with automatic cleanup.

  This is a convenience function that combines `unique_enforcer_name/0`,
  `Acx.EnforcerSupervisor.start_enforcer/2`, and automatic cleanup.

  Returns `{:ok, enforcer_name: ename}` which can be used directly in test setup.

  ## Examples

      setup do
        setup_enforcer("path/to/config.conf")
      end

      test "some test", %{enforcer_name: ename} do
        # Use ename here
      end
  """
  @spec setup_enforcer(String.t()) :: {:ok, keyword()}
  def setup_enforcer(cfile) when is_binary(cfile) do
    ename = unique_enforcer_name()

    case Acx.EnforcerSupervisor.start_enforcer(ename, cfile) do
      {:ok, _pid} ->
        ExUnit.Callbacks.on_exit(fn -> cleanup_enforcer(ename) end)
        {:ok, enforcer_name: ename}

      {:error, reason} ->
        raise "Failed to start enforcer with config '#{cfile}': #{inspect(reason)}"
    end
  end

  @doc """
  Sets up a unique enforcer with a custom name prefix.

  ## Examples

      setup do
        setup_enforcer("my_test", "path/to/config.conf")
      end
  """
  @spec setup_enforcer(String.t(), String.t()) :: {:ok, keyword()}
  def setup_enforcer(prefix, cfile) when is_binary(prefix) and is_binary(cfile) do
    ename = unique_enforcer_name(prefix)

    case Acx.EnforcerSupervisor.start_enforcer(ename, cfile) do
      {:ok, _pid} ->
        ExUnit.Callbacks.on_exit(fn -> cleanup_enforcer(ename) end)
        {:ok, enforcer_name: ename}

      {:error, reason} ->
        raise "Failed to start enforcer with config '#{cfile}': #{inspect(reason)}"
    end
  end
end

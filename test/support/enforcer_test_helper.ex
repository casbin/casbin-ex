defmodule Acx.EnforcerTestHelper do
  @moduledoc """
  Test helpers for working with Enforcers in async tests.

  This module provides utilities to create isolated enforcer instances
  for async tests, preventing race conditions caused by shared global state.

  ## Usage

  ### Basic Usage with `use ExUnit.Case, async: true`

      defmodule MyTest do
        use ExUnit.Case, async: true
        import Acx.EnforcerTestHelper

        setup do
          # Create an isolated enforcer with a unique name
          {:ok, ename, pid} = start_test_enforcer("my_enforcer", config_file)
          
          # The enforcer will be automatically stopped when the test exits
          {:ok, ename: ename}
        end

        test "my test", %{ename: ename} do
          Acx.EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
          assert Acx.EnforcerServer.allow?(ename, ["alice", "data", "read"])
        end
      end

  ### Manual Control

      defmodule MyTest do
        use ExUnit.Case, async: true
        import Acx.EnforcerTestHelper

        test "manual control" do
          ename = unique_enforcer_name("test")
          {:ok, pid} = Acx.EnforcerServer.start_link_isolated(ename, config_file)
          
          try do
            # Your test code here
          after
            stop_enforcer(ename)
          end
        end
      end
  """

  alias Acx.{EnforcerServer, EnforcerSupervisor}

  @doc """
  Generates a unique enforcer name for testing.

  ## Example

      iex> unique_enforcer_name("test")
      "test_123456789"
  """
  def unique_enforcer_name(base_name) when is_binary(base_name) do
    EnforcerServer.unique_name(base_name)
  end

  @doc """
  Starts an isolated enforcer for testing and registers cleanup.

  This function:
  1. Generates a unique enforcer name based on the provided base name
  2. Starts an isolated enforcer process (not using global ETS cache)
  3. Registers an `on_exit` callback to stop the enforcer when the test completes

  Returns `{:ok, enforcer_name, pid}` on success, or `{:error, reason}` on failure.

  ## Options

  - `:supervised` - Whether to start the enforcer under a supervisor (default: false)

  ## Example

      setup do
        {:ok, ename, _pid} = start_test_enforcer("my_test", "path/to/config.conf")
        {:ok, ename: ename}
      end
  """
  def start_test_enforcer(base_name, config_file, opts \\ []) do
    supervised = Keyword.get(opts, :supervised, false)
    ename = unique_enforcer_name(base_name)

    result =
      if supervised do
        EnforcerSupervisor.start_enforcer_isolated(ename, config_file)
      else
        EnforcerServer.start_link_isolated(ename, config_file)
      end

    case result do
      {:ok, pid} ->
        # Register cleanup to stop the enforcer when test exits
        ExUnit.Callbacks.on_exit(fn ->
          stop_enforcer(ename)
        end)

        {:ok, ename, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stops an enforcer process gracefully.

  This function attempts to stop the enforcer using GenServer.stop/1.
  If the process doesn't exist or is already stopped, it silently succeeds.

  ## Example

      stop_enforcer("my_enforcer_123")
  """
  def stop_enforcer(ename) do
    pid = GenServer.whereis(via_tuple(ename))

    if pid && Process.alive?(pid) do
      GenServer.stop(via_tuple(ename), :normal, 5000)
    end

    :ok
  catch
    :exit, _ -> :ok
  end

  # Returns a tuple used to register and lookup an enforcer process by name
  defp via_tuple(ename) do
    {:via, Registry, {Acx.EnforcerRegistry, ename}}
  end
end

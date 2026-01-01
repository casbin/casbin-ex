defmodule Casbin.TestHelper do
  @moduledoc """
  Helper functions for testing with isolated enforcer instances in async tests.

  Provides utilities to create unique enforcer names and manage test enforcer lifecycle.
  """

  alias Casbin.EnforcerSupervisor
  alias Casbin.EnforcerServer

  @doc """
  Generates a unique enforcer name for isolated testing.
  """
  @spec unique_enforcer_name(String.t()) :: String.t()
  def unique_enforcer_name(prefix \\ "") do
    ref = inspect(make_ref()) |> String.replace(~r/[^a-zA-Z0-9]/, "_")
    timestamp = System.system_time(:microsecond)
    random = :rand.uniform(999_999)

    prefix_part = if prefix != "", do: "#{prefix}_", else: ""
    "test_enforcer_#{prefix_part}#{ref}_#{timestamp}_#{random}"
  end

  @doc """
  Starts an enforcer process for testing.
  """
  @spec start_test_enforcer(String.t(), String.t()) ::
          {:ok, pid()} | {:error, term()}
  def start_test_enforcer(enforcer_name, config_file) do
    EnforcerSupervisor.start_enforcer(enforcer_name, config_file)
  end

  @doc """
  Cleans up a test enforcer by stopping its process and removing it from the ETS table.
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
  """
  @spec reset_test_enforcer(String.t(), String.t()) :: :ok | {:error, term()}
  def reset_test_enforcer(enforcer_name, config_file) do
    EnforcerServer.reset_configuration(enforcer_name, config_file)
  end
end

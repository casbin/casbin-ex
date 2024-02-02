defmodule Acx do
  use Application
  require Logger

  def start(_type, _args) do
    children =
      Application.get_env(:acx, :registry)
      |> case do
        Registry ->
          [
            {Registry, keys: :unique, name: Acx.EnforcerRegistry},
            Acx.EnforcerSupervisor
          ]

        Horde.Registry ->
          # Start Horde an libcluster related supervisors. The registry needs to come before the TaskSupervisor.
          [
            {Cluster.Supervisor,
             [Application.get_env(:libcluster, :topologies), [name: Acx.ClusterSupervisor]]},
            Acx.Horde.HordeRegistry,
            Acx.EnforcerSupervisor,
            Acx.Horde.NodeObserver
          ]

        unknown ->
          Logger.error("Unsupported registry value configured: #{inspect(unknown)}")
          []
      end

    :ets.new(:enforcers_table, [:public, :named_table])

    opts = [strategy: :one_for_one, name: Acx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

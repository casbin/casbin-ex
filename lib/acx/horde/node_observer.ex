defmodule Acx.Horde.NodeObserver do
  use GenServer

  alias Acx.Horde.HordeRegistry
  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, [])

  def init(_) do
    :net_kernel.monitor_nodes(true, node_type: :visible)

    {:ok, nil}
  end

  def handle_info({:nodeup, node, _node_type}, state) do
    set_members(HordeRegistry)
    set_members(Acx.EnforcerSupervisor)

    Logger.info("Now communicating with #{node}.")

    {:noreply, state}
  end

  def handle_info({:nodedown, node, _node_type}, state) do
    set_members(HordeRegistry)
    set_members(Acx.EnforcerSupervisor)

    Logger.info("Lost contact with #{node}.")

    {:noreply, state}
  end

  defp set_members(name) do
    members = Enum.map([Node.self() | Node.list()], &{name, &1})

    :ok = Horde.Cluster.set_members(name, members)
  end
end

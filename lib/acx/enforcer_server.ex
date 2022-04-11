defmodule Acx.EnforcerServer do
  @moduledoc """
  An enforcer process that holds an `Enforcer` struct as its state.
  """

  use GenServer

  require Logger

  alias Acx.Enforcer

  #
  # Client Public Interface
  #

  @doc """
  Loads and constructs an enforcer from the given config file `cfile`,
  and spawns a new process under the given name `ename` taking the
  (just constructed) enforcer as its initial state.
  """
  def start_link(ename, cfile) do
    GenServer.start_link(
      __MODULE__,
      {ename, cfile},
      name: via_tuple(ename)
    )
  end

  @doc """
  Returns `true` if the given request `req` is allowed under the enforcer
  whose name given by `ename`.

  Returns `false`, otherwise.

  See `Enforcer.allow?/2` for more information.
  """
  def allow?(ename, req) do
    GenServer.call(via_tuple(ename), {:allow?, req})
  end

  @doc """
  Adds a new policy rule with key given by `key` and a list of
  attribute values `attr_values` to the enforcer.

  See `Enforcer.add_policy/2` for more information.
  """
  def add_policy(ename, {key, attrs}) do
    GenServer.call(via_tuple(ename), {:add_policy, {key, attrs}})
  end

  @doc """
  Loads policy rules from external file given by the name `pfile` and
  adds them to the enforcer.

  See `Enforcer.load_policies!/2` for more details.
  """
  def load_policies(ename, pfile) do
    GenServer.call(via_tuple(ename), {:load_policies, pfile})
  end

  @doc """
  Returns a list of policies in the given enforcer that match the
  given criteria.

  See `Enforcer.list_policies/2` for more details.
  """
  def list_policies(ename, criteria) do
    GenServer.call(via_tuple(ename), {:list_policies, criteria})
  end

  @doc """
  Makes `role1` inherit from (or has role ) `role2`. The `mapping_name`
  should be one of the names given in the model configuration file under
  the `role_definition` section. For example if your role definition look
  like this:

  [role_definition]
  g = _, _

  then `mapping_name` should be the atom `:g`.

  See `Enforcer.add_mapping_policy/2` for more details.
  """
  def add_mapping_policy(ename, {mapping_name, role1, role2}) do
    GenServer.call(
      via_tuple(ename),
      {:add_mapping_policy, {mapping_name, role1, role2}}
    )
  end

  def add_mapping_policy(ename, {mapping_name, role1, role2, dom}) do
    GenServer.call(
      via_tuple(ename),
      {:add_mapping_policy, {mapping_name, role1, role2, dom}}
    )
  end

  @doc """
  Loads mapping policies from a csv file and adds them to the enforcer.

  See `Enforcer.load_mapping_policies!/2` for more details.
  """
  def load_mapping_policies(ename, fname) do
    GenServer.call(via_tuple(ename), {:load_mapping_policies, fname})
  end

  @doc """
  Return a fresh enforcer.

  See `Enforcer.init/1` for more details.
  """
  def reset_configuration(ename, cfile) do
    GenServer.call(via_tuple(ename), {:reset_configuration, cfile})
  end

  @doc """
  Adds a user-defined function to the enforcer.

  See `Enforcer.add_fun/2` for more details.
  """
  def add_fun(ename, {fun_name, fun}) do
    GenServer.call(via_tuple(ename), {:add_fun, {fun_name, fun}})
  end

  #
  # Server Callbacks
  #

  def init({ename, cfile}) do
    case create_new_or_lookup_enforcer(ename, cfile) do
      {:error, reason} ->
        {:stop, reason}

      {:ok, enforcer} ->
        Logger.info("Spawned an enforcer process named '#{ename}'")
        {:ok, enforcer}
    end
  end

  def handle_call({:allow?, req}, _from, enforcer) do
    allowed = enforcer |> Enforcer.allow?(req)
    {:reply, allowed, enforcer}
  end

  def handle_call({:add_policy, {key, attrs}}, _from, enforcer) do
    case Enforcer.add_policy(enforcer, {key, attrs}) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
      new_enforcer ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:load_policies, pfile}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.load_policies!(pfile)
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:list_policies, criteria}, _from, enforcer) do
    policies = enforcer |> Enforcer.list_policies(criteria)
    {:reply, policies, enforcer}
  end

  def handle_call({:add_mapping_policy, mapping}, _from, enforcer) do
    case Enforcer.add_mapping_policy(enforcer, mapping) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
      new_enforcer ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:load_mapping_policies, fname}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.load_mapping_policies!(fname)
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:reset_configuration, cfile}, _from, enforcer) do
    case Enforcer.init(cfile) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:add_fun, {fun_name, fun}}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.add_fun({fun_name, fun})
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  #
  # Helpers
  #

  # Returns a tuple used to register and lookup an enforcer process
  # by name
  defp via_tuple(ename) do
    {:via, Registry, {Acx.EnforcerRegistry, ename}}
  end

  # Returns the name of `self`.
  defp self_name() do
    Registry.keys(Acx.EnforcerRegistry, self()) |> List.first
  end

  # Creates a new enforcer or lookups existing one in the ets table.
  defp create_new_or_lookup_enforcer(ename, cfile) do
    case :ets.lookup(:enforcers_table, ename) do
      [] ->
        case Enforcer.init(cfile) do
          {:error, reason} ->
            {:error, reason}

          {:ok, enforcer} ->
            :ets.insert(:enforcers_table, {ename, enforcer})
            {:ok, enforcer}
        end

      [{^ename, enforcer}] ->
        {:ok, enforcer}
    end
  end

end

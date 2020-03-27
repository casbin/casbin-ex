defmodule Acx.EnforcerServer do
  use GenServer

  require Logger

  alias Acx.Model

  #
  # Client Public Interface
  #

  @doc """
  Builds a model from the given `conf_file`, and spwans a new
  enforcer process under the given name `enforcer_name`.
  """
  def start_link(enforcer_name, conf_file) do
    GenServer.start_link(
      __MODULE__,
      {enforcer_name, conf_file},
      name: via_tuple(enforcer_name)
    )
  end

  @doc """
  Returns `true` if `request` is allowed, otherwise `false`.
  """
  def enforce(enforcer_name, request) do
    GenServer.call(via_tuple(enforcer_name), {:enforce, request})
  end

  # Policy management.

  @doc """
  Adds a single policy rule with key given `key` and attributes list
  given by `attrs` to the enforcer with the given name `enforcer_name`.

  Returns the newly created policy rule or error if the given policy
  rule already existed.
  """
  def add_policy(enforcer_name, {key, attrs}) do
    GenServer.call(via_tuple(enforcer_name), {:add_policy, {key, attrs}})
  end

  @doc """
  Gets all policy rules from the enforcer whose name given by
  `enforcer_name` that match the given `clauses`.

  A valid clauses should be a map or a keywords list.

  For example, in order to get all policy rules with the key `:p`
  and the `act` attribute is `"read"`, you can call `get_policies_by/2`
  function with second argument:

    `%{key: :p, act: "read"}`

  By passing in an empty map or an empty list to the second argument
  of the function `get_policies_by/2`, you'll effectively get all policy
  rules in the enforcer (without filtered).
  """
  def get_policies_by(enforcer_name, clauses) do
    GenServer.call(via_tuple(enforcer_name), {:get_policies_by, clauses})
  end

  #
  # Server Callbacks
  #

  def init({enforcer_name, conf_file}) do
    case create_new_or_lookup_enforcer(enforcer_name, conf_file) do
      {:error, reason} ->
        {:stop, reason}

      {:ok, enforcer} ->
        Logger.info("Spawned an enforcer process named '#{enforcer_name}'")
        {:ok, enforcer}
    end
  end

  # Enforce a request
  # def handle_call({:enforce, request}, _from, prev_state) do
  #   %{model: model, policies: policies} = prev_state
  #   case Model.create_request(model, request) do
  #     {:error, reason} ->
  #       {:reply, {:error, reason}, prev_state}

  #     {:ok, r} ->
  #       allowed =
  #         policies
  #         |> Enum.filter(fn p -> Matcher.match?(r, p) end)
  #         |> PolicyEffect.reduce(policy_effect)

  #       {:reply, allowed, prev_state}
  #   end
  # end

  # Add policy
  def handle_call({:add_policy, {key, attrs}}, _from, prev_state) do
    %{model: model, policies: old_policies} = prev_state
    case create_new_policy(model, old_policies, {key, attrs}) do
      {:error, reason} ->
        {:reply, {:error, reason}, prev_state}

      {:ok, policy} ->
        new_policies = [policy | old_policies]
        new_state = %{prev_state | policies: new_policies}

        :ets.insert(:enforcers_table, {self_name(), new_state})

        {:reply, policy, new_state}
    end
  end

  # Filter policy rules

  def handle_call({:get_policies_by, clauses}, _from, prev_state)
  when is_map(clauses) or is_list(clauses) do
    filtered_policies =
      prev_state.policies
      |> Enum.filter(fn %{key: key, attrs: attrs} ->
      list = [{:key, key} | attrs]
      clauses |> Enum.all?(fn c -> c in list end)
    end)

    {:reply, filtered_policies, prev_state}
  end

  def handle_call({:get_policies_by, _}, _from, prev_state) do
    {:reply, {:error, :invalid_argument}, prev_state}
  end

  #
  # Helpers
  #

  # Returns a tuple used to register and lookup an enforcer process
  # by name
  defp via_tuple(enforcer_name) do
    {:via, Registry, {Acx.EnforcerRegistry, enforcer_name}}
  end

  # Returns the name of `self`.
  defp self_name() do
    Registry.keys(Acx.EnforcerRegistry, self()) |> List.first
  end

  # Creates a new enforcer or lookups existing one in the ets table.
  defp create_new_or_lookup_enforcer(enforcer_name, conf_file) do
    case :ets.lookup(:enforcers_table, enforcer_name) do
      [] ->
        case Model.init(conf_file) do
          {:error, reason} ->
            {:error, reason}

          {:ok, model} ->
            enforcer = %{model: model, policies: []}
            :ets.insert(:enforcers_table, {enforcer_name, enforcer})
            {:ok, enforcer}
        end

      [{^enforcer_name, enforcer}] ->
        {:ok, enforcer}
    end
  end

  # Create a new policy
  defp create_new_policy(model, old_policies, {key, attrs}) do
    case Model.create_policy(model, {key, attrs}) do
      {:error, reason} ->
        {:error, reason}

      {:ok, policy} ->
        case Enum.member?(old_policies, policy) do
          true ->
            {:error, :already_existed}

          false ->
            {:ok, policy}
        end
    end
  end


  # defstruct model: nil, policies: []

  # alias __MODULE__

  # alias Model
  # alias Acx.Request
  # alias Acx.Policy
  # alias Acx.PolicyEffect
  # alias Acx.Matcher

  # @doc """
  # Creates a new enforcer based on the given config file `conf_file` and
  # the policies file `policies_file`.
  # """
  # def new(conf_file, policies_file) do
  #   %Enforcer{}
  #   |> build_model!(conf_file)
  #   |> load_policies!(policies_file)
  # end

  # @doc """
  # Returns `true` if `request` is allowed, otherwise `false`.
  # """
  # def enforce(%Enforcer{model: model, policies: policies}, request) do
  #   %{request_definition: request_definition} = model
  #   case Request.new(request, request_definition) do
  #     {:error, reason} ->
  #       {:error, reason}

  #     {:ok, r} ->
  #       %{policy_effect: policy_effect, matchers: m} = model
  #       policies
  #       |> Enum.filter(fn p -> match?(m, r, p) end)
  #       |> PolicyEffect.reduce(policy_effect)
  #   end
  # end

  # #
  # # Helpers.
  # #

  # defp build_model!(enforcer, conf_file) do
  #   case Model.new(conf_file) do
  #     {:error, msg} ->
  #       raise ArgumentError, message: msg

  #     {:ok, model} ->
  #       %{enforcer | model: model}
  #   end
  # end

  # defp load_policies!(enforcer, policies_file) do
  #   %{model: m} = enforcer

  #   policies =
  #     policies_file
  #     |> File.read!
  #     |> String.split("\n", trim: true)
  #     |> Enum.map(&String.split(&1, ~r{,\s*}))
  #     |> Enum.map(fn [k | rest] -> [String.to_atom(k) | rest] end)
  #     |> Enum.filter(fn [k | _] -> Model.has_policy_key?(m, k) end)
  #     |> Enum.map(fn [k | rest] -> Model.create_policy!(m, {k, rest}) end)

  #   %{enforcer | policies: policies}
  # end

  # defp match?(%Matcher{} = m, %Request{} = r, %Policy{} = p) do
  #   env = build_env(r, p)
  #   case Matcher.eval(m, env) do
  #     # TODO: It does feel right to return `false` when we encounter
  #     # error when evaluating the matcher expression.
  #     {:error, _reason} ->
  #       false

  #     {:ok, result} ->
  #       # TODO: Any truthy value is considered `true`?
  #       !!result
  #   end
  # end

  # defp build_env(%Request{} = r, %Policy{} = p) do
  #   %{
  #     r.key => r.attrs,
  #     p.key => p.attrs
  #   }
  # end

end

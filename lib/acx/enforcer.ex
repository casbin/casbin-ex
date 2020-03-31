defmodule Acx.Enforcer do
  @moduledoc """
  TODO
  """

  defstruct [
    model: nil,
    policies: [],
    env: %{}
  ]

  alias Acx.Model

  @type t() :: %__MODULE__{
    model: Model.t(),
    policies: [Model.Policy.t()],
    env: map()
  }

  @doc """
  Loads and contructs a model from the given config file `conf_file`.
  """
  @spec init(String.t()) :: {:ok, t()} | {:error, String.t()}
  def init(conf_file) when is_binary(conf_file) do
    case Model.init(conf_file) do
      {:error, reason} ->
        {:error, reason}

      {:ok, model} ->
        {:ok, %__MODULE__{model: model, env: init_env()}}
    end
  end

  @doc """
  Adds a new policy rule with key given by `key` and a list of
  attribute values `attr_values` to the enforcer.
  """
  @spec add_policy(t(), {atom(), [String.t()]}) :: t() | {:error, String.t()}
  def add_policy(
    %__MODULE__{model: model, policies: policies} = enforcer,
    {key, attrs}
  ) do
    case Model.create_policy(model, {key, attrs}) do
      {:error, reason} ->
        {:error, reason}

      {:ok, policy} ->
        case Enum.member?(policies, policy) do
          true ->
            {:error, :already_existed}

          false ->
            %{enforcer | policies: [policy | policies]}
        end
    end
  end

  @doc """
  Adds a new policy rule with key given by `key` and a list of attribute
  values `attr_values` to the enforcer.
  """
  def add_policy!(%__MODULE__{} = enforcer, {key, attrs}) do
    case add_policy(enforcer, {key, attrs}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  @doc """
  Loads policy rules from external file given by the name `pfile` and
  adds them to the enforcer.

  A valid policy file should be a `*.csv` file, in which each line must
  have the following format:

    `pkey, attr1, attr2, attr3`

  in which `pkey` is the key of the policy rule, this key must match the
  policy definition in the enforcer. `attr1`, `attr2`, ... are the
  value of attributes specified in the policy definition.
  """
  def load_policies!(
    %__MODULE__{model: m, policies: old_policies} = enforcer,
    pfile
  ) do
    new_policies =
      pfile
      |> File.read!
      |> String.split("\n", trim: true)
      |> Enum.map(&String.split(&1, ~r{,\s*}))
      |> Enum.map(fn [key | attrs] -> [String.to_atom(key) | attrs] end)
      |> Enum.filter(fn [key | _] -> Model.has_policy_key?(m, key) end)
      |> Enum.map(fn [key | attrs] -> Model.create_policy!(m, {key, attrs}) end)

    %{enforcer | policies: Enum.uniq(new_policies ++ old_policies)}
  end


  @doc """
  Returns a list of policies in the given enforcer that match the
  given criteria.

  For example, in order to get all policy rules with the key `:p`
  and the `act` attribute is `"read"`, you can call `list_policies/2`
  function with second argument:

  `%{key: :p, act: "read"}`

  By passing in an empty map or an empty list to the second argument
  of the function `list_policies/2`, you'll effectively get all policy
  rules in the enforcer (without filtered).
  """
  def list_policies(
    %__MODULE__{policies: policies},
    criteria
  ) when is_map(criteria) or is_list(criteria) do
    policies
    |> Enum.filter(fn %{key: key, attrs: attrs} ->
      list = [{:key, key} | attrs]
      criteria |> Enum.all?(fn c -> c in list end)
    end)
  end

  def list_policies(%__MODULE__{policies: policies}), do: policies

  @doc """
  Returns `true` if `request` is allowed, otherwise `false`.
  """
  def allow?(%__MODULE__{model: model} = e, request) do
    matched_policies = list_matched_policies(e, request)
    Model.allow?(model, matched_policies)
  end

  @doc """
  Returns a list of policy rules in the given enforcer that match the
  given `request`.
  """
  def list_matched_policies(
    %__MODULE__{model: model, policies: policies} = e,
    request
  ) do
    case Model.create_request(model, request) do
      {:error, _reason} ->
        []

      {:ok, req} ->
        policies
        |> Enum.filter(fn pol ->
          env = build_env(e, req, pol)
          Model.match?(model, req, pol, env)
        end)
    end
  end

  #
  # Build in stubs function
  #

  @doc """
  Returns `true` if the given string `str` matches the pattern
  string `^pattern$`.
  """
  def regex_match?(str, pattern) do
    case Regex.compile("^#{pattern}$") do
      {:error, _} ->
        false

      {:ok, r} ->
        Regex.match?(r, str)
    end
  end

  #
  # Helpers
  #

  defp build_env(
    %__MODULE__{env: env},
    %{key: r, attrs: r_attrs},
    %{key: p, attrs: p_attrs}
  ) do
    env
    |> Map.put(p, p_attrs)
    |> Map.put(r, r_attrs)
  end

  defp init_env do
    %{
      regex_match?: &regex_match?/2
    }
  end

end

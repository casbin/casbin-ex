defmodule Acx.Enforcer do
  @moduledoc """
  """

  @enforce_keys [:model]
  defstruct [
    model: nil,
    policies: [],
    env: %{}
  ]

  alias __MODULE__
  alias Acx.Model
  alias Acx.Matcher

  @doc """
  Loads and contructs a model from the given config file `conf_file`.
  """
  def init(conf_file) when is_binary(conf_file) do
    case Model.init(conf_file) do
      {:error, reason} ->
        {:error, reason}

      {:ok, model} ->
        {:ok, %Enforcer{model: model, env: init_env()}}
    end
  end

  @doc """
  Adds a new policy rule with key given by `key` and attributes list
  given by `attrs` to the `enforcer`.
  """
  def add_policy(
    %Enforcer{model: model, policies: policies} = enforcer,
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
    %Enforcer{policies: policies},
    criteria
  ) when is_map(criteria) or is_list(criteria) do
    policies
    |> Enum.filter(fn %{key: key, attrs: attrs} ->
      list = [{:key, key} | attrs]
      criteria |> Enum.all?(fn c -> c in list end)
    end)
  end

  def list_policies(%Enforcer{policies: policies}), do: policies

  @doc """
  Returns `true` if `request` is allowed, otherwise `false`.
  """
  def enforce(%Enforcer{model: model} = e, request) do
    matched_policies = list_matched_policies(e, request)
    Model.allow?(model, matched_policies)
  end

  @doc """
  Returns a list of policy rules in the given enforcer that match the
  given `request`.
  """
  def list_matched_policies(
    %Enforcer{model: model, policies: policies} = e,
    request
  ) do
    case Model.create_request(model, request) do
      {:error, _reason} ->
        []

      {:ok, req} ->
        policies |> Enum.filter(fn pol -> match?(e, req, pol) end)
    end
  end

  #
  # Build in stubs function
  #

  @doc """
  Returns `true` if the given string `str` matches the pattern
  string `pattern`.
  """
  def regex_match?(str, pattern) do
    case Regex.compile(pattern) do
      {:error, _} ->
        false

      {:ok, r} ->
        Regex.match?(r, str)
    end
  end

  #
  # Helpers
  #

  # Returns `true` if the given request matches the given policy.
  # Returns `false`, otherwise.
  defp match?(
    %Enforcer{model: %{matchers: matchers}, env: env},
    %{key: r, attrs: r_attrs},
    %{key: p, attrs: p_attrs}
  ) do
    environment =
      env
      |> Map.put(p, p_attrs)
      |> Map.put(r, r_attrs)

    !!(Matcher.eval!(matchers, environment))
  end

  defp init_env do
    %{
      regex_match?: &regex_match?/2
    }
  end

end

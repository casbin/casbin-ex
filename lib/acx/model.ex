defmodule Acx.Model do
  @moduledoc """
  This module defines the structure to represent a PERM (Policy, Effect,
  Request, Matchers) meta model. See [1] for more information.

  The `Model` struct is structured like so:

  - A request definition (`request`) defines how incoming requests are
  structured. An example would be `r = sub, obj, act`, this means the
  system expect all requests to be a tuple of three items, in which,
  first item associated with an attribute named `sub`, second `obj`, and
  third `act`, respectively. An example of a valid rquest would be
  `["bob", "alice_data", "read"]` (Can `bob` `read` `alice_data`?). When
  this request is sent to the system it's interpreted as:
  `r.sub = "bob"`, `r.obj = "alice_data"`, and `r.act = "read"`.

  You can think of the relationship between a request definition and
  requests is like that of class and instances in object oriented
  programming. A request definition is like a `class`, and a request
  is like an `instance` of that class.

  - A list of policy definitions (`policies`). `Model` supports
  multiple policy definitions, each with its own key and a set of
  attributes. A policy definition defines how authorization rules
  are structured.The relationship between a policy definition and
  policies is like that of request definition and request, except,
  each policy rule must have a key associated with it so as to identify
  from which definition does the policy derive.
  (A request doesn't need a key since there is only one request
  definition in a given model).

  All policy rules have in common the `eft` attribute and it can take
  only one of the two values `"allow"` or `"deny"`. So you don't have
  to specify the `eft` attribute when defining a policy, and when
  constructing a policy rule if `eft` is absent, it is defaulted to
  `"allow"` (allowed rule).

  An example of a policy definition would be `p = sub, obj, act`, this
  means all policy rules derived from this definition would have a key
  name `p` and a set of four attributes `sub, obj, act, eft`. Examples
  of valid rules derived from this definition would be:
  `p, alice, data1, read` (`eft` is implicitly `"allow"`) or
  `p, alice, data1, read, deny` (`eft` is explicitly `"deny"`)

  - `matcher`: a boolean expression used to determine how requests and
  policies are matched. Given the request definition `r = sub, obj, act`
  and policy definition `p = sub, obj, act`, the simplest example
  of a matchers expression would be:
  `m = r.sub == p.sub && r.obj == p.obj && r.act == p.act`.

  When a new request is sent to our system, it is matched against
  all the policy rules in the system using this matchers expression.
  Then all the matched policy rules (those that make matchers
  expression return `true`) get sent to the `effect` to make the
  final decision.

  - Policy effect `effect` defines whether the request should be approved
  or denied if multiple policy rules match the request.

  For now, only the following policy effect rules are valid:

  1. `"some(where(p.eft==allow))"`: if there's any matched policy rule of
  type `allow`, the final effect is `allow`. Which means if there's no
  match or all matches are of type `deny`, the final effect is `deny`.

  2. `"!some(where(p.eft==deny))"`: if there's no matched policy rules of
  type `deny`, the final effect is `allow`.

  - A list of role definitions (`role_mappers`). (TODO)

  [1] - https://vicarie.in/posts/generalized-authz.html
  """

  defstruct [
    request: nil,
    policies: [],
    matcher: nil,
    effect: nil,
    role_mappings: []
  ]

  alias Acx.Model.{
    Config,
    RequestDefinition,
    PolicyDefinition,
    PolicyEffect,
    Matcher,
    Request,
    Policy
  }

  @type t() :: %__MODULE__ {
    request: RequestDefinition.t(),
    policies: [PolicyDefinition.t()],
    matcher: Matcher.t(),
    effect: PolicyEffect.t(),
    role_mappings: [atom()]
  }

  @doc """
  Initializes a model given the config file `cfile`.
  """
  @spec init(String.t()) :: {:ok, t()} | {:error, String.t()}
  def init(cfile) when is_binary(cfile) do
    case Config.new(cfile) do
      {:error, reason} ->
          {:error, reason}

      %Config{sections: sections} ->
        %__MODULE__{}
        |> validate_required_sections(sections)
        |> build(:request)
        |> build(:policies)
        |> build(:effect)
        |> build(:matcher)
        |> build(:role_mappings)
        |> case do
             {:error, reason} ->
               {:error, reason}

             {:ok, model, _} ->
               {:ok, model}
           end
    end
  end

  @doc """
  Creates a new request.
  """
  @spec create_request(t(), [String.t()]) :: {:ok, Request.t()}
  | {:error, String.t()}
  def create_request(%__MODULE__{request: rd}, attr_values) do
    RequestDefinition.create_request(rd, attr_values)
  end

  @doc """
  Creates a new policy.
  """
  @spec create_policy(t(), [String.t()]) :: {:ok, Policy.t()}
  | {:error, String.t()}
  def create_policy(
    %__MODULE__{policies: definitions},
    {key, attr_values}
  ) do
    found_matched_definition =
      definitions
      |> Enum.find(fn %PolicyDefinition{key: k} -> k === key end)

    case found_matched_definition do
      nil ->
        {:error, "policy with key `#{key}` is undefined"}

      definition ->
        PolicyDefinition.create_policy(definition, attr_values)
    end
  end

  def create_policy(%__MODULE__{}, _), do: {:error, "invalid policy"}

  @doc """
  Creates a new policy.
  """
  def create_policy!(%__MODULE__{} = m, {key, attr_values}) do
    case create_policy(m, {key, attr_values}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      {:ok, policy} ->
        policy
    end
  end

  @doc """
  Returns `true` if there is a policy definition with the given key
  `key` in the model.

  Returns `false`, otherwise.
  """
  @spec has_policy_key?(t(), atom()) :: boolean()
  def has_policy_key?(%__MODULE__{policies: definitions}, key) do
    definitions
    |> Enum.find(fn %PolicyDefinition{key: k} -> k === key end)
    |> case do
         nil ->
           false

         _ ->
           true
       end
  end

  @doc """
  Returns `true` if the given request matches the given policy.

  Returns `false`, otherwise.
  """
  @spec match?(t(), Request.t(), Policy.t(), map()) :: boolean()
  def match?(
    %__MODULE__{matcher: matcher},
    %Request{key: r, attrs: r_attrs},
    %Policy{key: p, attrs: p_attrs},
    env \\ %{}
  ) do
    environment =
      env
      |> Map.put(p, p_attrs)
      |> Map.put(r, r_attrs)

    !!(Matcher.eval!(matcher, environment))
  end

  @doc """
  Takes a list of matched policies and determines whether the final effect
  is `allow` or `deny` based on the `policy_effect`
  """
  def allow?(%__MODULE__{effect: pe}, matched_policies) do
    pe |> PolicyEffect.allow?(matched_policies)
  end

  #
  # Helpers.
  #

  defp validate_required_sections(model, sections) do
    cond do
      sections[:request_definition] == nil ->
        missing_section_error("request_definition")

      sections[:policy_definition] == nil ->
        missing_section_error("policy_definition")

      sections[:policy_effect] == nil ->
        missing_section_error("policy_effect")

      sections[:matchers] == nil ->
        missing_section_error("matchers")

      true ->
        {:ok, model, sections}
    end
  end

  defp build({:error, msg}, _), do: {:error, msg}

  # Build request definition
  defp build({:ok, model, sections}, :request) do
    sections
    |> validate_request_definition()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, rd} ->
           model = %{model | request: rd}
           {:ok, model, sections}
       end
  end

  # Build policy definition
  defp build({:ok, model, sections}, :policies) do
    sections
    |> validate_policy_definition()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, definitions} ->
           model = %{model | policies: definitions}
           {:ok, model, sections}
       end
  end

  # Build policy effect
  defp build({:ok, model, sections}, :effect) do
    sections
    |> validate_effect_rule()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, pe} ->
           model = %{model | effect: pe}
           {:ok, model, sections}
       end
  end

  # Build matcher program
  defp build({:ok, model, sections}, :matcher) do
    sections
    |> validate_matchers()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, m} ->
           model = %{model | matcher: m}
           {:ok, model, sections}
       end
  end

  # Build role definitions
  defp build({:ok, model, sections}, :role_mappings) do
    sections
    |> validate_role_mappings()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, mappings} ->
           model = %{model | role_mappings: mappings}
           {:ok, model, sections}
       end
  end

  defp missing_section_error(section_name) do
    {
      :error,
      "missing `#{section_name}` section in the config file"
    }
  end

  # Validate request definition
  defp validate_request_definition(sections) do
    case sections[:request_definition] do
      [{key, value}] when is_atom(key) and value !== "" ->
        {:ok, RequestDefinition.new(key, value)}

      _ ->
        {:error, "invalid request definition"}
    end
  end

  # Validate policy definition
  defp validate_policy_definition(sections) do
    sections[:policy_definition]
    |> Enum.map(fn {key, value} -> PolicyDefinition.new(key, value) end)
    |> case do
         [] ->
           {:error, "policy definition required"}

         definitions ->
           {:ok, definitions}
       end
  end

  # Validate policy effect rule
  @effect_rules ["some(where(p.eft==allow))", "!some(where(p.eft==deny))"]
  defp validate_effect_rule(sections) do
    case sections[:policy_effect] do
      [{_key, rule}] when rule in @effect_rules ->
        {:ok, PolicyEffect.new(rule)}

      _ ->
        {:error, "invalid policy effect rule"}
    end
  end

  # Validate matchers
  defp validate_matchers(sections) do
    case sections[:matchers] do
      [{_key, value}] when value !== "" ->
        case Matcher.new(value) do
          {:error, reason} ->
            {:error, reason}

          %Matcher{} = m ->
            {:ok, m}
        end

      _ ->
        {:error, "invalid matchers"}
    end
  end

  # Validate role mappings (a.k.a role definition)

  defp validate_role_mappings(sections) do
    case sections[:role_definition] do
      nil ->
        {:ok, []}

      definitions ->
        case check_role_definition(definitions) do
          {:error, reason} ->
            {:error, reason}

          :ok ->
            {:ok, Keyword.keys(definitions)}
        end
    end
  end

  # A valid role definition should be `{key, "_,_"}` in which
  # `key` must be an atom.
  defp check_role_definition([]), do: :ok
  defp check_role_definition([{_key, "_,_"} | rest]) do
    check_role_definition(rest)
  end
  defp check_role_definition([{key, val} | _]) do
    {:error, "invalid role definition: `#{key}=#{val}`"}
  end

end

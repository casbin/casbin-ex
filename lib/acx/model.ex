defmodule Acx.Model do
  defstruct [
    request_definition: nil,
    policy_definition: nil,
    policy_effect: nil,
    matchers: nil
  ]

  alias __MODULE__

  alias Acx.Config
  alias Acx.RequestDefinition
  alias Acx.PolicyDefinition
  alias Acx.PolicyEffect
  alias Acx.Matcher
  alias Acx.Helpers

  @effect_rules ["some(where(p.eft==allow))", "!some(where(p.eft==deny))"]

  def init(conf_file) do
    case Config.new(conf_file) do
      {:error, reason} ->
          {:error, reason}

      {:ok, %Config{sections: sections}} ->
        %Model{}
        |> validate_sections(sections)
        |> build(:request_definition)
        |> build(:policy_definition)
        |> build(:policy_effect)
        |> build(:matchers)
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
  def create_request(%Model{request_definition: rd}, request_data) do
    RequestDefinition.create_request(rd, request_data)
  end

  @doc """
  Creates a new policy
  """
  def create_policy(
    %Model{policy_definition: definitions},
    {key, attrs_data}
  ) when is_atom(key) and is_list(attrs_data) do
    found_matched_definition =
      definitions
      |> Enum.find(fn %PolicyDefinition{key: k} -> k == key end)

    case found_matched_definition do
      nil ->
        {:error, "policy with key `#{key}` is undefined"}

      definition ->
        PolicyDefinition.create_policy(definition, attrs_data)
    end
  end

  def create_policy(%Model{}, _), do: {:error, "invalid policy"}

  @doc """
  Creates a new policy.
  """
  def create_policy!(%Model{} = m, {key, attrs_data}) do
    case create_policy(m, {key, attrs_data}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      {:ok, policy} ->
        policy
    end
  end

  @doc """
  Returns `true` if the model has a policy definition with the given `key`.

  Returns `false`, otherwise.
  """
  def has_policy_key?(%Model{policy_definition: definitions}, key) do
    found =
      definitions
      |> Enum.find(fn %PolicyDefinition{key: k} -> k === key end)
    found !== nil
  end

  @doc """
  Takes a list of matched policies and determines whether the final effect
  is `allow` or `deny` based on the `policy_effect`
  """
  def allow?(%Model{policy_effect: pe}, matched_policies) do
    # TODO: is the name `reduce` appropriate?
    PolicyEffect.reduce(matched_policies, pe)
  end

  #
  # Helpers.
  #

  defp validate_sections(model, sections) do
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
  defp build({:ok, model, sections}, :request_definition) do
    sections
    |> validate_request_definition()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, rd} ->
           model = %{model | request_definition: rd}
           {:ok, model, sections}
       end
  end

  # Build policy definition
  defp build({:ok, model, sections}, :policy_definition) do
    sections
    |> validate_policy_definition()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, definitions} ->
           model = %{model | policy_definition: definitions}
           {:ok, model, sections}
       end
  end

  # Build policy effect
  defp build({:ok, model, sections}, :policy_effect) do
    sections
    |> validate_effect_rule()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, pe} ->
           model = %{model | policy_effect: pe}
           {:ok, model, sections}
       end
  end

  # Build matcher program
  defp build({:ok, model, sections}, :matchers) do
    sections
    |> validate_matchers()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, m} ->
           model = %{model | matchers: m}
           {:ok, model, sections}
       end
  end

  #
  # Helpers.
  #

  defp missing_section_error(section_name) do
    {
      :error,
      "missing `#{section_name}` section in the config file"
    }
  end

  # Validate request definition
  defp validate_request_definition(sections) do
    case sections[:request_definition] do
      [{key, value}] when value !== "" ->
        {:ok, RequestDefinition.new(key, value)}

      _ ->
        {:error, "invalid request definition"}
    end
  end

  # Validate policy definition
  defp validate_policy_definition(sections) do
    # TODO: There are few things to consider:
    #
    # 1. We don't want any `value` to be empty string.
    #
    # 2. Error on duplicate keys or just remove duplicates and continue?
    #
    # 3. I don't like the way you handle empty list below.
    #
    # 4. This looks like a mess to me. (refactor it!)
    list = sections[:policy_definition]

    case Helpers.has_duplicate_key?(list) do
      true ->
        {:error, "duplicate keys in policy definition"}

      false ->
        list
        |> Enum.map(fn {key, value} -> PolicyDefinition.new(key, value) end)
        |> case do
             [] ->
               {:error, "policy definition required"}

             definitions ->
               {:ok, definitions}
           end
    end
  end

  # Validate policy effect rule
  defp validate_effect_rule(sections) do
    case sections[:policy_effect] do
      [{_key, rule}] when rule in @effect_rules ->
        {:ok, PolicyEffect.new(rule)}

      _ ->
        {:error, "invalid policy effect"}
    end
  end

  # Validate matchers
  defp validate_matchers(sections) do
    case sections[:matchers] do
      [{_key, value}] when value !== "" ->
        case Matcher.new(value) do
          {:error, reason} ->
            {:error, reason}

          {:ok, matchers} ->
            {:ok, matchers}
        end

      _ ->
        {:error, "invalid matchers"}
    end
  end

end

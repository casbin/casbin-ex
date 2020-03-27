defmodule Acx.PolicyDefinition do
  @moduledoc """
  A policy definition has two parts:

    - A key, typically the atom `:p`.

    - And a list of attributes in which each attibute is an atom.

    - The atom `:eft` is the common attribute of all policy definitions.
  """

  @enforce_keys [:key, :attrs]
  defstruct key: nil, attrs: []

  alias __MODULE__
  alias Acx.Policy

  @reserved_attr :eft
  @valid_eft ["allow", "deny"]

  @doc """
  Creates a policy definition based on the given `key` and a comma
  separated string of attributes.

  ## Examples

     iex> Acx.PolicyDefinition.new(:p, "sub, obj, act")
     %Acx.PolicyDefinition{attrs: [:sub, :obj, :act, :eft], key: :p}

     iex> Acx.PolicyDefinition.new(:some_key, "attr1,attr2")
     %Acx.PolicyDefinition{attrs: [:attr1, :attr2, :eft], key: :some_key}

     iex> Acx.PolicyDefinition.new(:p, "sub, obj, act, eft")
     %Acx.PolicyDefinition{attrs: [:sub, :obj, :act, :eft], key: :p}

     iex> Acx.PolicyDefinition.new(:p, "sub, obj, act, sub, eft")
     %Acx.PolicyDefinition{attrs: [:sub, :obj, :act, :eft], key: :p}
  """
  def new(key, attrs_str) do
    attrs =
      attrs_str
      |> String.trim()
      |> String.split(~r{,\s*}, trim: true)
      |> Enum.map(&String.to_atom/1)
      |> Enum.uniq()
      |> Enum.filter(fn a -> a != @reserved_attr end)

    %PolicyDefinition{key: key, attrs: attrs ++ [:eft]}
  end

  @doc """
  Creates a policy based on the given policy definition `definition`,
  and the given attributes data `data`.
  """
  def create_policy(%PolicyDefinition{} = definition, data) do
    case validate_policy(definition, data) do
      {:error, reason} ->
        {:error, reason}

      {:ok, attrs} ->
        {:ok, Policy.new(definition.key, attrs)}
    end
  end


  # Validate the new policy attributes data `data` against the given
  # policy definition.
  defp validate_policy(%PolicyDefinition{attrs: attrs}, data) do
    attrs_len = length(attrs)
    data_len = length(data)

    cond do
      data_len != attrs_len && data_len != attrs_len - 1 ->
        {:error, "invalid policy"}

      data_len == attrs_len && List.last(data) not in @valid_eft ->
        {:error, "invalid value for the `eft` attribute: #{List.last(data)}"}

      !Enum.all?(data, &valid_attr_type?/1) ->
        {:error, "invalid attribute type"}

      data_len == attrs_len ->
        {:ok, Enum.zip(attrs, data)}

      true ->
        {:ok, Enum.zip(attrs, data ++ ["allow"])}
    end
  end

  defp valid_attr_type?(value) do
    is_binary(value) || is_number(value)
  end

end

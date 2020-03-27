defmodule Acx.Policy do
  @moduledoc """
  A policy has two parts:

    - A key, typically the atom `:p`.

    - A list of key-value pairs, in which `key` is the name of one of
      the attributes of the policy, and `value` is the value of such
      attribute.

    - All policies have one common attribute named `:eft` and its value
      can only be either `"allow"` or `"deny"`.
  """

  @enforce_keys [:key, :attrs]
  defstruct key: nil, attrs: []

  alias __MODULE__

  @doc """
  Create new policy based on the given `key` and the list of
  attributes `attrs`.

  ## Examples

     iex> Acx.Policy.new(:p, [sub: "alice", obj: "data1", act: "read"])
     %Acx.Policy{key: :p, attrs: [sub: "alice", obj: "data1", act: "read"]}
  """
  def new(key, attrs) do
    %Policy{key: key, attrs: attrs}
  end

  @doc """
  Returns `true` if the policy is of type `allow`.
  Returns `false` otherwise.
  """
  def allow?(%Policy{attrs: attrs}), do: attrs[:eft] === "allow"
end

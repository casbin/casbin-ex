defmodule Acx.RequestDefinition do
  @moduledoc """
  A request definition has two parts:

    - A key, typically the atom `:r`.

    - And a list of attributes in which each attibute is an atom.
  """

  @enforce_keys [:key, :attrs]
  defstruct key: nil, attrs: []

  alias __MODULE__
  alias Acx.Request

  @doc """
  Creates a request definition based on the given `key` and a comma
  separated string of attributes.

  ## Examples

     iex> Acx.RequestDefinition.new(:r, "sub, obj, act")
     %Acx.RequestDefinition{attrs: [:sub, :obj, :act], key: :r}

     iex> Acx.RequestDefinition.new(:k, "attr1,attr2")
     %Acx.RequestDefinition{attrs: [:attr1, :attr2], key: :k}
  """
  def new(key, attrs_str) do
    attrs =
      attrs_str
      |> String.trim()
      |> String.split(~r{,\s*}, trim: true)
      |> Enum.map(&String.to_atom/1)
      |> Enum.uniq()

    %RequestDefinition{key: key, attrs: attrs}
  end

  @doc """
  Creates a request based on the given `definition` and `request_data`.

  ## Examples

     iex> rd = Acx.RequestDefinition.new(:r, "sub,obj,act")
     %Acx.RequestDefinition{attrs: [:sub, :obj, :act], key: :r}
     iex> Acx.RequestDefinition.create_request(rd, ["alice", "data1", "read"])
     {
       :ok,
       %Acx.Request{
         key: :r,
         attrs: [sub: "alice", obj: "data1", act: "read"]
       }
     }
     iex> Acx.RequestDefinition.create_request(rd, ["alice", "read"])
     {:error, "invalid request"}
     iex> Acx.RequestDefinition.create_request(rd, [])
     {:error, "invalid request"}
  """
  def create_request(%RequestDefinition{} = definition, request_data) do
    case valid_request?(definition, request_data) do
      false ->
        {:error, "invalid request"}

      true ->
        key = definition.key
        attrs = Enum.zip(definition.attrs, request_data)
        {:ok, Request.new(key, attrs)}
    end
  end

  @doc """
  Returns `true` if the request matches the request definition,
  `false` otherwise. A valid request should be a list of length equals
  to the number of attributes specified in the definition. And each item
  in the list should be either a `string` or a `number`.

  ## Examples

     iex> rd = Acx.RequestDefinition.new(:r, "sub, obj, act")
     %Acx.RequestDefinition{attrs: [:sub, :obj, :act], key: :r}
     iex> Acx.RequestDefinition.valid_request?(rd, ["alice", "data1", "read"])
     true
     iex> Acx.RequestDefinition.valid_request?(rd, ["alice", "data1"])
     false
     iex> Acx.RequestDefinition.valid_request?(rd, [:alice, :data1, :read])
     false
  """
  def valid_request?(%RequestDefinition{attrs: attrs}, request) do
    (length(attrs) == length(request)) &&
      Enum.all?(request, &valid_attr_type?/1)
  end

  defp valid_attr_type?(value) do
    is_binary(value) || is_number(value)
  end

end

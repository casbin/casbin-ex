defmodule Acx.Request do
  @moduledoc """
  A request has two parts:

    - A key, typically the atom `:r`.

    - A list of key-value pairs, in which `key` is the name of one of
      the attributes of the request, and `value` is the value of such
      attribute.
  """

  @enforce_keys [:key, :attrs]
  defstruct key: nil, attrs: []

  alias __MODULE__

  @doc """
  Creates a new request based on the given `key` and `attrs`

  ## Examples:

     iex> Acx.Request.new(:r, [sub: "alice", obj: "data1", act: "read"])
     %Acx.Request{key: :r, attrs: [sub: "alice", obj: "data1", act: "read"]}
  """
  def new(key, attrs) do
    %Request{key: key, attrs: attrs}
  end

end

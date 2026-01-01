defmodule Casbin.Model.Request do
  @moduledoc """
  This module defines a structure to represent a request.
  A request has two parts:

  - A key, typically the atom `:r`.
  - A list of key-value pairs, in which `key` is the name of one of
  the attributes of the request, and `value` is the value of such
  attribute.
  """

  defstruct key: nil, attrs: []

  @type key() :: atom()
  @type attr() :: atom()
  @type attr_value() :: String.t() | number()
  @type t() :: %__MODULE__{
          key: key(),
          attrs: [{attr(), attr_value()}]
        }

  @doc """
  Creates a new request based on the given `key` and a list of attributes.
  """
  def new(key, attrs) do
    %__MODULE__{key: key, attrs: attrs}
  end
end

defmodule Acx.ModelTest do
  use ExUnit.Case, async: true
  alias Acx.Model

  alias Acx.Model.{
    RequestDefinition,
    PolicyDefinition,
    PolicyEffect,
    Matcher,
    Request,
    Policy
  }

  doctest Acx.Model
end

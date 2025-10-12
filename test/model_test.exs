defmodule Acx.ModelTest do
  use ExUnit.Case, async: true
  alias Acx.Model

  alias Acx.Model.{
    Matcher,
    Policy,
    PolicyDefinition,
    PolicyEffect,
    Request,
    RequestDefinition
  }

  doctest Acx.Model
end

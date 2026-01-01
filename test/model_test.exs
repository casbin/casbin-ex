defmodule Casbin.ModelTest do
  use ExUnit.Case, async: true
  alias Casbin.Model

  alias Casbin.Model.{
    Matcher,
    Policy,
    PolicyDefinition,
    PolicyEffect,
    Request,
    RequestDefinition
  }

  doctest Casbin.Model
end

defmodule Acx.PolicyEffectTest do
  use ExUnit.Case
  doctest Acx.PolicyEffect

  alias Acx.PolicyDefinition
  alias Acx.PolicyEffect

  @allow_override "some(where(p.eft==allow))"
  @deny_override "!some(where(p.eft==deny))"

  describe "reduce/2" do
    setup do
      definition = PolicyDefinition.new(:p, "sub,obj,act")

      {:ok, p1} = PolicyDefinition.create_policy(
        definition,
        ["alice", "data1", "read"]
      )

      {:ok, p2} = PolicyDefinition.create_policy(
        definition,
        ["alice", "data1", "read", "deny"]
      )

      {:ok, allow_policy: p1, deny_policy: p2}
    end

    test "when effect rule is `allow_override`",
      %{allow_policy: allow_p, deny_policy: deny_p} do
      pe = PolicyEffect.new(@allow_override)

      assert PolicyEffect.reduce([allow_p, deny_p], pe) === true
      assert PolicyEffect.reduce([allow_p], pe) === true
      assert PolicyEffect.reduce([deny_p], pe) === false
      assert PolicyEffect.reduce([], pe) === false
    end

    test "when effect rule is `deny_override`",
      %{allow_policy: allow_p, deny_policy: deny_p} do
      pe = PolicyEffect.new(@deny_override)

      assert PolicyEffect.reduce([allow_p, deny_p], pe) === false
      assert PolicyEffect.reduce([deny_p], pe) === false
      assert PolicyEffect.reduce([allow_p], pe) === true
      assert PolicyEffect.reduce([], pe) === true
    end
  end
end

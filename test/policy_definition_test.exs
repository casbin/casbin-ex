defmodule Acx.PolicyDefinitionTest do
  use ExUnit.Case
  doctest Acx.PolicyDefinition

  alias Acx.PolicyDefinition
  alias Acx.Policy

  describe "create_policy/2" do
    @policy_key :p
    @valid_attr_values ["alice", "data1", "read"]

    setup do
      definition = PolicyDefinition.new(@policy_key, "sub,obj,act")
      {:ok, definition: definition}
    end

    test "with valid data creates policy", %{definition: definition} do
      assert {:ok, policy} = PolicyDefinition.create_policy(
        definition,
        @valid_attr_values
      )

      assert %Policy{
        key: @policy_key,
        attrs: [sub: "alice", obj: "data1", act: "read", eft: "allow"]
      } == policy
    end

    test "creates `allow` policy", %{definition: definition} do
      assert {:ok, policy} = PolicyDefinition.create_policy(
        definition,
        @valid_attr_values ++ ["allow"]
      )

      assert %Policy{
        key: @policy_key,
        attrs: [sub: "alice", obj: "data1", act: "read", eft: "allow"]
      } == policy
    end

    test "creates `deny` policy", %{definition: definition} do
      assert {:ok, policy} = PolicyDefinition.create_policy(
        definition,
        @valid_attr_values ++ ["deny"]
      )

      assert %Policy{
        key: @policy_key,
        attrs: [sub: "alice", obj: "data1", act: "read", eft: "deny"]
      } == policy
    end

    test "returns error if invalid value for `eft` attribute",
      %{definition: definition} do
      assert {:error, reason} = PolicyDefinition.create_policy(
        definition,
        @valid_attr_values ++ ["foo"]
      )
      assert reason == "invalid value for the `eft` attribute: foo"
    end

    test "returns error if invalid number of attributes",
      %{definition: definition} do
      assert {:error, reason} = PolicyDefinition.create_policy(
        definition,
        ["alice", "read"]
      )
      assert reason == "invalid policy"
    end

    test "returns error if invalid attribute type",
      %{definition: definition} do
      assert {:error, reason} = PolicyDefinition.create_policy(
        definition,
        [:alice, "data1", "read"]
      )
      assert reason == "invalid attribute type"
    end

  end

end

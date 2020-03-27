defmodule Acx.EnforcerTest do
  use ExUnit.Case
  doctest Acx.Enforcer

  alias Acx.Enforcer
  alias Acx.Model
  alias Acx.RequestDefinition
  alias Acx.PolicyDefinition
  alias Acx.PolicyEffect
  alias Acx.Matcher

  describe "init/1" do
    test "ACL model" do
      conf_file = "./data/acl.conf" |> Path.expand(__DIR__)
      assert {:ok, enforcer} = Enforcer.init(conf_file)

      assert %Enforcer{
        model: model,
        policies: policies,
      } = enforcer

      # Check model

      assert %Model{
        request_definition: request_definition,
        policy_definition: policy_definition,
        policy_effect: policy_effect,
        matchers: matchers
      } = model

      assert %RequestDefinition{
        key: :r,
        attrs: [:sub, :obj, :act]
      } === request_definition

      assert [
        %PolicyDefinition{
          key: :p,
          attrs: [:sub, :obj, :act, :eft]
        }
      ] === policy_definition

      assert %PolicyEffect{
        rule: "some(where(p.eft==allow))"
      } === policy_effect

      assert %Matcher{
        prog: [
          {:fetch_attr, %{key: :r, attr: :sub}},
          {:fetch_attr, %{key: :p, attr: :sub}},
          {:eq},
          {:fetch_attr, %{key: :r, attr: :obj}},
          {:fetch_attr, %{key: :p, attr: :obj}},
          {:eq},
          {:and},
          {:fetch_attr, %{key: :r, attr: :act}},
          {:fetch_attr, %{key: :p, attr: :act}},
          {:eq},
          {:and}
        ]
      } === matchers

      # Check rest

      assert policies === []
    end

    test "ACL with superuser" do
      conf_file =
        "./data/acl_with_superuser.conf"
        |> Path.expand(__DIR__)

      assert {:ok, enforcer} = Enforcer.init(conf_file)

      assert %Enforcer{
        model: model,
        policies: policies
      } = enforcer

      # Check model

      assert %Model{
        request_definition: request_definition,
        policy_definition: policy_definition,
        policy_effect: policy_effect,
        matchers: matchers
      } = model

      assert %RequestDefinition{
        key: :r,
        attrs: [:sub, :obj, :act]
      } === request_definition

      assert [
        %PolicyDefinition{
          key: :p,
          attrs: [:sub, :obj, :act, :eft]
        }
      ] === policy_definition

      assert %PolicyEffect{
        rule: "some(where(p.eft==allow))"
      } === policy_effect

      assert %Matcher{
        prog: [
          {:fetch_attr, %{key: :r, attr: :sub}},
          {:fetch_attr, %{key: :p, attr: :sub}},
          {:eq},
          {:fetch_attr, %{key: :r, attr: :obj}},
          {:fetch_attr, %{key: :p, attr: :obj}},
          {:eq},
          {:and},
          {:fetch_attr, %{key: :r, attr: :act}},
          {:fetch_attr, %{key: :p, attr: :act}},
          {:eq},
          {:and},
          {:fetch_attr, %{key: :r, attr: :sub}},
          {:push, "root"},
          {:eq},
          {:or}
        ]
      } === matchers

      # Check rest

      assert policies === []
    end

  end

end

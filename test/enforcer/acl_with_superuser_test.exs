defmodule Acx.Enforcer.AclWithSuperuserTest do
  use ExUnit.Case

  alias Acx.Enforcer
  alias Acx.Model
  alias Acx.RequestDefinition
  alias Acx.PolicyDefinition
  alias Acx.PolicyEffect
  alias Acx.Matcher
  alias Acx.Policy

  @cfile "../data/acl_with_superuser.conf" |> Path.expand(__DIR__)
  @pfile "../data/acl_with_superuser.csv" |> Path.expand(__DIR__)

  describe "init/1" do
    test "correctly initialized the ACL with superuser model" do
      assert {:ok, enforcer} = Enforcer.init(@cfile)
      assert %Enforcer{model: %Model{}, policies: []} = enforcer
    end

    test "correctly initialized request definition" do
      assert {:ok, enforcer} = Enforcer.init(@cfile)

      assert %Enforcer{
        model: %Model{request_definition: request_definition}
      } = enforcer

      assert %RequestDefinition{
        key: :r,
        attrs: [:sub, :obj, :act]
      } === request_definition
    end

    test "correctly initialized policy definition" do
      assert {:ok, enforcer} = Enforcer.init(@cfile)

      assert %Enforcer{
        model: %Model{policy_definition: policy_definition}
      } = enforcer

      assert [
        %PolicyDefinition{
          key: :p,
          attrs: [:sub, :obj, :act, :eft]
        }
      ] === policy_definition
    end

    test "correctly initialized policy effect rule" do
      assert {:ok, enforcer} = Enforcer.init(@cfile)

      assert %Enforcer{
        model: %Model{policy_effect: policy_effect}
      } = enforcer

      assert %PolicyEffect{
        rule: "some(where(p.eft==allow))"
      } === policy_effect
    end

    test "correctly compiled matcher program" do
      assert {:ok, enforcer} = Enforcer.init(@cfile)

      assert %Enforcer{
        model: %Model{matchers: matchers}
      } = enforcer

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
    end

  end

end

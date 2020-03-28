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

  @policies [
    %Policy{
      key: :p,
      attrs: [sub: "alice", obj: "data1", act: "read", eft: "allow"]
    },
    %Policy{
      key: :p,
      attrs: [sub: "bob", obj: "data2", act: "write", eft: "allow"]
    }
  ]

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

  describe "add_policy/2" do
    @policy_key :p
    @sub "alice"
    @obj "data1"
    @act "read"

    setup do
      {:ok, enforcer} = Enforcer.init(@cfile)
      {:ok, enforcer: enforcer}
    end

    test "with valid data adds new policy rule to the enforcer",
      %{enforcer: enforcer} do
      rule = {@policy_key, [@sub, @obj, @act]}

      assert %Enforcer{
        policies: policies
      } = enforcer |> Enforcer.add_policy(rule)

      assert [
        %Policy{
          key: @policy_key,
          attrs: [sub: @sub, obj: @obj, act: @act, eft: "allow"]
        }
      ] === policies
    end

    test "returns error if policy rule elready existed",
      %{enforcer: enforcer} do
      rule = {@policy_key, [@sub, @obj, @act]}
      enforcer = enforcer |> Enforcer.add_policy(rule)

      assert {:error, reason} = enforcer |> Enforcer.add_policy(rule)
      assert reason === :already_existed
    end

    test "adds new allow policy rule to the enforcer if the `eft`
    attribute explicitly specified as 'allow'", %{enforcer: enforcer} do
      rule = {@policy_key, [@sub, @obj, @act, "allow"]}

      assert %Enforcer{
        policies: policies
      } = enforcer |> Enforcer.add_policy(rule)

      assert [
        %Policy{
          key: :p,
          attrs: [sub: @sub, obj: @obj, act: @act, eft: "allow"]
        }
      ] === policies
    end

    test "adds new deny policy rule to the enforcer if the `eft`
    attribute explicitly specified as 'deny'", %{enforcer: enforcer} do
      rule = {@policy_key, [@sub, @obj, @act, "deny"]}

      assert %Enforcer{
        policies: policies
      } = enforcer |> Enforcer.add_policy(rule)

      assert [
        %Policy{
          key: :p,
          attrs: [sub: @sub, obj: @obj, act: @act, eft: "deny"]
        }
      ] === policies
    end

    test "returns error if the value of `eft` attribute is neither
    'allow' nor 'deny'", %{enforcer: enforcer} do
      rule = {@policy_key, [@sub, @obj, @act, "foo"]}

      assert {:error, reason} = enforcer |> Enforcer.add_policy(rule)
      assert reason === "invalid value for the `eft` attribute: foo"
    end

    test "returns error if the specified policy key does not
    match the policy definition", %{enforcer: enforcer} do
      rule = {:q, [@sub, @obj, @act]}

      assert {:error, reason} = enforcer |> Enforcer.add_policy(rule)
      assert reason === "policy with key `q` is undefined"
    end

    test "returns error if attribute type is neither number nor
    string", %{enforcer: enforcer} do
      rule = {@policy_key, [@sub, @obj, :get]}
      assert {:error, reason} = enforcer |> Enforcer.add_policy(rule)
      assert reason === "invalid attribute type"
    end

    test "returns error if invalid policy rule",
      %{enforcer: enforcer} do
      rule = {@policy_key, [@sub, @obj]}
      assert {:error, reason} = enforcer |> Enforcer.add_policy(rule)
      assert reason === "invalid policy"
    end
  end

  describe "load_policies!/2" do
    test "successfully loaded and added new policy rules to the enforcer" do
      assert {:ok, enforcer} = Enforcer.init(@cfile)

      assert %Enforcer{
        policies: policies
      } = enforcer |> Enforcer.load_policies!(@pfile)

      assert policies === @policies
    end
  end

  describe "list_policies/2" do
    setup do
      {:ok, enforcer} = Enforcer.init(@cfile)
      enforcer = enforcer |> Enforcer.load_policies!(@pfile)
      {:ok, enforcer: enforcer}
    end

    test "returns all policies in the enforcer by default",
      %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer) === @policies
    end

    test "returns all policies with key `:p`", %{enforcer: e} do
      assert Enforcer.list_policies(e, %{key: :p}) === @policies
    end

    test "returns all policies where `sub` is `alice`",
      %{enforcer: e} do
      assert Enforcer.list_policies(e, %{sub: "alice"}) ===
        [
          %Policy{
            key: :p,
            attrs: [sub: "alice", obj: "data1", act: "read", eft: "allow"]
          }
        ]
    end

    test "returns all policies where `sub` is `bob`",
      %{enforcer: e} do
      assert Enforcer.list_policies(e, %{sub: "bob"}) ===
        [
          %Policy{
            key: :p,
            attrs: [sub: "bob", obj: "data2", act: "write", eft: "allow"]
          }
        ]
    end

    test "returns an empty list if no policies match the given criteria",
      %{enforcer: e} do
      assert Enforcer.list_policies(e, %{sub: "foo"}) === []
    end
  end

  describe "allow?/2" do
    @test_cases [
      {["alice", "data1", "read"], true},
      {["bob", "data2", "write"], true},

      {["alice", "data1", "write"], false},
      {["alice", "data2", "read"], false},
      {["alice", "data2", "write"], false},

      {["bob", "data1", "read"], false},
      {["bob", "data1", "write"], false},
      {["bob", "data2", "read"], false},

      {["root", "data1", "read"], true},
      {["root", "data1", "write"], true},
      {["root", "data1", "whatever"], true},

      {["root", "data2", "read"], true},
      {["root", "data2", "write"], true},
      {["root", "data2", "whatever"], true},

      {["root", "whatever", "read"], true},
      {["root", "whatever", "write"], true},
      {["root", "whatever", "whatever"], true}
    ]

    setup do
      {:ok, enforcer} = Enforcer.init(@cfile)
      enforcer = enforcer |> Enforcer.load_policies!(@pfile)
      {:ok, enforcer: enforcer}
    end

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect req}",
      %{enforcer: e} do
        assert Enforcer.allow?(e, unquote(req)) === unquote(res)
      end
    end)
  end

end

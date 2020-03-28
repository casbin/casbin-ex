defmodule Acx.Enforcer.RestfulModelTest do
  use ExUnit.Case

  alias Acx.Enforcer
  alias Acx.Model
  alias Acx.RequestDefinition
  alias Acx.PolicyDefinition
  alias Acx.PolicyEffect
  alias Acx.Matcher
  alias Acx.Policy

  @conf_file "../data/restful.conf" |> Path.expand(__DIR__)
  @pfile "../data/restful.csv" |> Path.expand(__DIR__)
  @policy_effect_rule "some(where(p.eft==allow))"
  @policies [
    %Acx.Policy{
      attrs: [
        sub: "alice",
        obj: "/alice_data/.*",
        act: "GET",
        eft: "allow"
      ],
      key: :p
},
    %Acx.Policy{
      attrs: [
        sub: "alice",
        obj: "/alice_data/resource1",
        act: "POST",
        eft: "allow"
      ],
      key: :p
    },
    %Acx.Policy{
      attrs: [
        sub: "bob",
        obj: "/alice_data/resource2",
        act: "GET",
        eft: "allow"
      ],
      key: :p
    },
    %Acx.Policy{
      attrs: [
        sub: "bob",
        obj: "/bob_data/.*",
        act: "POST",
        eft: "allow"
      ],
      key: :p
    },
    %Acx.Policy{
      attrs: [
        sub: "cathy",
        obj: "/cathy_data",
        act: "(GET)|(POST)",
        eft: "allow"
      ],
      key: :p
    }
  ]

  describe "init/1" do
    test "successfully initialized the model" do
      assert {:ok, enforcer} = Enforcer.init(@conf_file)

      assert %Enforcer{
        model: %Model{},
        policies: []
      } = enforcer
    end

    test "the initial policy rules must be empty" do
      assert {:ok, enforcer} = Enforcer.init(@conf_file)
      assert %Enforcer{
        policies: policies
      } = enforcer
      assert policies === []
    end

    test "correctly initilized request definition" do
      assert {:ok, enforcer} = Enforcer.init(@conf_file)

      assert %Enforcer{
        model: %Model{request_definition: request_definition}
      } = enforcer

      assert %RequestDefinition{
        key: :r,
        attrs: [:sub, :obj, :act]
      } === request_definition
    end

    test "correctly initilized policy definition" do
      assert {:ok, enforcer} = Enforcer.init(@conf_file)

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
      assert {:ok, enforcer} = Enforcer.init(@conf_file)

      assert %Enforcer{
        model: %Model{policy_effect: policy_effect}
      } = enforcer

      assert %PolicyEffect{
        rule: @policy_effect_rule
      } === policy_effect
    end

    test "correctly compiled the matcher program" do
      assert {:ok, enforcer} = Enforcer.init(@conf_file)

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
          {:call, %{name: :regex_match?, arity: 2}},
          {:and},
          {:fetch_attr, %{key: :r, attr: :act}},
          {:fetch_attr, %{key: :p, attr: :act}},
          {:call, %{name: :regex_match?, arity: 2}},
          {:and}
        ]
      } === matchers
    end
  end

  describe "add_policy/2" do
    @policy_key :p
    @sub "alice"
    @obj "/alice_data/.*"
    @act "GET"

    setup do
      {:ok, enforcer} = Enforcer.init(@conf_file)
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
      assert {:ok, enforcer} = Enforcer.init(@conf_file)

      assert %Enforcer{
        policies: policies
      } = enforcer |> Enforcer.load_policies!(@pfile)

      assert policies === @policies
    end
  end

  describe "list_policies/2" do
    setup do
      {:ok, enforcer} = Enforcer.init(@conf_file)
      enforcer = enforcer |> Enforcer.load_policies!(@pfile)
      {:ok, enforcer: enforcer}
    end

    test "returns all policies if no criteria provided",
      %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer) === @policies
    end

    test "returns all policy rules where `sub` is `alice`",
      %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer, %{sub: "alice"}) ===
        [
          %Policy{
            key: :p,
            attrs: [
              sub: "alice",
              obj: "/alice_data/.*",
              act: "GET",
              eft: "allow"
            ]
          },

          %Policy{
            key: :p,
            attrs: [
              sub: "alice",
              obj: "/alice_data/resource1",
              act: "POST",
              eft: "allow"
            ]
          }
        ]
    end

    test "returns all policy rules where `sub` is `bob`",
      %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer, %{sub: "bob"}) ===
        [
          %Policy{
            key: :p,
            attrs: [
              sub: "bob",
              obj: "/alice_data/resource2",
              act: "GET",
              eft: "allow"
            ]
          },

          %Policy{
            key: :p,
            attrs: [
              sub: "bob",
              obj: "/bob_data/.*",
              act: "POST",
              eft: "allow"
            ]
          }
        ]
    end

    test "returns all policy rules where `sub` is `cathy`",
      %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer, %{sub: "cathy"}) ===
        [
          %Policy{
            key: :p,
            attrs: [
              sub: "cathy",
              obj: "/cathy_data",
              act: "(GET)|(POST)",
              eft: "allow"
            ]
          }
        ]
    end

    test "returns all policy rules where `act` is `GET`",
      %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer, %{act: "GET"}) ===
        [
          %Policy{
            key: :p,
            attrs: [
              sub: "alice",
              obj: "/alice_data/.*",
              act: "GET",
              eft: "allow"
            ]
          },
          %Policy{
            key: :p,
            attrs: [
              sub: "bob",
              obj: "/alice_data/resource2",
              act: "GET",
              eft: "allow"
            ]
          }
        ]
    end

    test "returns all policy rules where `act` is `POST`",
      %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer, %{act: "POST"}) ===
        [
          %Policy{
            key: :p,
            attrs: [
              sub: "alice",
              obj: "/alice_data/resource1",
              act: "POST",
              eft: "allow"
            ]
          },
          %Policy{
            key: :p,
            attrs: [
              sub: "bob",
              obj: "/bob_data/.*",
              act: "POST",
              eft: "allow"
            ]
          }
        ]
    end

    test "returns all policy rules match multiple criteria",
      %{enforcer: enforcer} do
      criteria = %{sub: "alice", act: "GET"}
      assert Enforcer.list_policies(enforcer, criteria) ===
        [
          %Policy{
            key: :p,
            attrs: [
              sub: "alice",
              obj: "/alice_data/.*",
              act: "GET",
              eft: "allow"
            ]
          }
        ]
    end

    test "returns an empty list if no policy rules match the given
    criteria", %{enforcer: enforcer} do
      assert Enforcer.list_policies(enforcer, %{sub: "foo"}) === []
    end
  end

  describe "allow?/2 when `sub` is `alice`" do
    @test_cases [
      {["alice", "/alice_data", "GET"], false},
      {["alice", "/alice_data/", "GET"], true},
      {["alice", "/alice_data/hello", "GET"], true},
      {["alice", "/alice_data/foo/baz", "GET"], true},

      {["alice", "/alice_data/resource1", "GET"], true},
      {["alice", "/alice_data/resource1", "POST"], true},

      {["alice", "/alice_data/resource2", "GET"], true},
      {["alice", "/alice_data/resource2", "POST"], false},

      {["alice", "/bob_data/", "GET"], false},
      {["alice", "/bob_data/", "POST"], false},
      {["alice", "/bob_data/foo", "GET"], false},
      {["alice", "/bob_data/foo", "POST"], false},

      {["alice", "/cathy_data/", "GET"], false},
      {["alice", "/cathy_data/", "POST"], false},
      {["alice", "/cathy_data/foo", "GET"], false},
      {["alice", "/cathy_data/foo", "POST"], false},
    ]

    setup do
      {:ok, enforcer} = Enforcer.init(@conf_file)
      enforcer = enforcer |> Enforcer.load_policies!(@pfile)
      {:ok, enforcer: enforcer}
    end


    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect req}`",
      %{enforcer: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "allow?/2 when `sub` is `bob`" do
    @test_cases [
      {["bob", "/bob_data/", "POST"], true},
      {["bob", "/bob_data/", "GET"], false},
      {["bob", "/bob_data/foo", "POST"], true},
      {["bob", "/bob_data/foo", "GET"], false},
      {["bob", "/bob_data/foo/baz", "POST"], true},
      {["bob", "/bob_data/foo/baz", "GET"], false},
      {["bob", "/bob_data/foo_baz", "POST"], true},
      {["bob", "/bob_data/foo_baz", "GET"], false},

      {["bob", "/alice_data/resource2", "GET"], true},
      {["bob", "/alice_data/resource2", "POST"], false},
      {["bob", "/alice_data/", "GET"], false},
      {["bob", "/alice_data/", "POST"], false},
      {["bob", "/alice_data/resource1", "GET"], false},
      {["bob", "/alice_data/resource1", "POST"], false},
      {["bob", "/alice_data/foo", "GET"], false},
      {["bob", "/alice_data/foo", "POST"], false},
      {["bob", "/alice_data/resource1/foo", "GET"], false},
      {["bob", "/alice_data/resource1/foo", "POST"], false},

      {["bob", "/cathy_data", "GET"], false},
      {["bob", "/cathy_data", "POST"], false},
      {["bob", "/cathy_data/", "GET"], false},
      {["bob", "/cathy_data/", "POST"], false},
      {["bob", "/cathy_data/foo", "GET"], false},
      {["bob", "/cathy_data/foo", "POST"], false},
      {["bob", "/cathy_data/foo/baz", "GET"], false},
      {["bob", "/cathy_data/foo/baz", "POST"], false},
    ]

    setup do
      {:ok, enforcer} = Enforcer.init(@conf_file)
      enforcer = enforcer |> Enforcer.load_policies!(@pfile)
      {:ok, enforcer: enforcer}
    end


    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect req}`",
      %{enforcer: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "allow?/2 when `sub` is `cathy`" do
    @test_cases [
      {["cathy", "/cathy_data", "POST"], true},
      {["cathy", "/cathy_data", "GET"], true},
      {["cathy", "/cathy_data/", "POST"], false},
      {["cathy", "/cathy_data/", "GET"], false},
      {["cathy", "/cathy_data/foo", "POST"], false},
      {["cathy", "/cathy_data/foo", "GET"], false},

      {["cathy", "/alice_data", "GET"], false},
      {["cathy", "/alice_data", "POST"], false},
      {["cathy", "/alice_data/", "GET"], false},
      {["cathy", "/alice_data/", "POST"], false},
      {["cathy", "/alice_data/resource1", "GET"], false},
      {["cathy", "/alice_data/resource1", "POST"], false},
      {["cathy", "/alice_data/resource2", "GET"], false},
      {["cathy", "/alice_data/resource2", "POST"], false},
      {["cathy", "/alice_data/foo", "GET"], false},
      {["cathy", "/alice_data/foo", "POST"], false},

      {["cathy", "/bob_data", "GET"], false},
      {["cathy", "/bob_data", "POST"], false},
      {["cathy", "/bob_data/", "GET"], false},
      {["cathy", "/bob_data/", "POST"], false},
      {["cathy", "/bob_data/foo", "GET"], false},
      {["cathy", "/bob_data/foo", "POST"], false},
    ]

    setup do
      {:ok, enforcer} = Enforcer.init(@conf_file)
      enforcer = enforcer |> Enforcer.load_policies!(@pfile)
      {:ok, enforcer: enforcer}
    end


    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect req}`",
      %{enforcer: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

end

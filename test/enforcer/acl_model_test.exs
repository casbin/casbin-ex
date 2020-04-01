defmodule Acx.Enforcer.AclModelTest do
  use ExUnit.Case, async: true
  alias Acx.Model.Policy
  alias Acx.Enforcer

  @cfile  "../data/acl.conf" |> Path.expand(__DIR__)
  @pfile  "../data/acl.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)
    e = e |> Enforcer.load_policies!(@pfile)
    {:ok, e: e}
  end

  describe "allow?/2" do
    @test_cases  [
      {["alice", "blog_post", "create"], true},
      {["alice", "blog_post", "delete"], true},
      {["alice", "blog_post", "modify"], true},
      {["alice", "blog_post", "read"], true},
      {["alice", "blog_post", "foo"], false},
      {["alice", "data", "create"], false},

      {["bob", "blog_post", "read"], true},
      {["bob", "blog_post", "create"], false},
      {["bob", "blog_post", "modify"], false},
      {["bob", "blog_post", "delete"], false},
      {["bob", "blog_post", "foo"], false},

      {["peter", "blog_post", "create"], true},
      {["peter", "blog_post", "modify"], true},
      {["peter", "blog_post", "read"], true},
      {["peter", "blog_post", "delete"], false},
      {["peter", "blog_post", "foo"], false},
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response #{res} for request #{inspect req}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "list_policies/2" do
    test "returns all policy rules by default", %{e: e} do
      policies = e |> Enforcer.list_policies()
      assert [
        # peter

        %Policy{
          key: :p,
          attrs: [sub: "peter", obj: "blog_post", act: "read", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "peter", obj: "blog_post", act: "modify", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"]
        },

        # bob

        %Policy{
          key: :p,
          attrs: [sub: "bob", obj: "blog_post", act: "read", eft: "allow"]
        },

        # alice

        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "read", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "modify", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "delete", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "create", eft: "allow"]
        }
      ] === policies
    end

    test "returns all policy rules for alice", %{e: e} do
      policies = e |> Enforcer.list_policies(%{sub: "alice"})

      assert [
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "read", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "modify", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "delete", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "create", eft: "allow"]
        }
      ] === policies
    end

    test "returns all policy rules for bob", %{e: e} do
      policies = e |> Enforcer.list_policies(%{sub: "bob"})
      assert [
        %Policy{
          key: :p,
          attrs: [sub: "bob", obj: "blog_post", act: "read", eft: "allow"]
        }
      ] === policies
    end

    test "returns all policy rules for peter", %{e: e} do
      policies = e |> Enforcer.list_policies(%{sub: "peter"})
      assert [
        %Policy{
          key: :p,
          attrs: [sub: "peter", obj: "blog_post", act: "read", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "peter", obj: "blog_post", act: "modify", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"]
        }
      ] === policies
    end

    test "returns all policy rules where `act` is `create`", %{e: e} do
      policies = e |> Enforcer.list_policies(%{act: "create"})
      assert [
        %Policy{
          key: :p,
          attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"]
        },
        %Policy{
          key: :p,
          attrs: [sub: "alice", obj: "blog_post", act: "create", eft: "allow"]
        },
      ] === policies
    end

    test "returns empty list if no policy rules match given criteria",
      %{e: e} do
      assert e |> Enforcer.list_policies(%{sub: "bob", act: "create"}) === []
    end

  end

end

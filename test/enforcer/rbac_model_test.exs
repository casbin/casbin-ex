defmodule Casbin.Enforcer.RbacModelTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer

  @cfile "../data/rbac.conf" |> Path.expand(__DIR__)
  @pfile "../data/rbac.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)

    e =
      e
      |> Enforcer.load_policies!(@pfile)
      |> Enforcer.load_mapping_policies!(@pfile)

    {:ok, e: e}
  end

  describe "allow?/2" do
    @test_cases [
      {["bob", "blog_post", "read"], true},
      {["bob", "blog_post", "create"], false},
      {["bob", "blog_post", "modify"], false},
      {["bob", "blog_post", "delete"], false},
      {["peter", "blog_post", "read"], true},
      {["peter", "blog_post", "create"], true},
      {["peter", "blog_post", "modify"], true},
      {["peter", "blog_post", "delete"], false},
      {["alice", "blog_post", "read"], true},
      {["alice", "blog_post", "create"], true},
      {["alice", "blog_post", "modify"], true},
      {["alice", "blog_post", "delete"], true}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "removed mapping policy allow?/2" do
    @test_cases [
      {["bob", "blog_post", "read"], true},
      {["bob", "blog_post", "create"], false},
      {["bob", "blog_post", "modify"], false},
      {["bob", "blog_post", "delete"], false},
      {["peter", "blog_post", "read"], false},
      {["peter", "blog_post", "create"], false},
      {["peter", "blog_post", "modify"], false},
      {["peter", "blog_post", "delete"], false},
      {["alice", "blog_post", "read"], true},
      {["alice", "blog_post", "create"], true},
      {["alice", "blog_post", "modify"], true},
      {["alice", "blog_post", "delete"], true}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        e = Enforcer.remove_mapping_policy(e, {:g, "peter", "author"})
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "removed intermediate mapping policy allow?/2" do
    @test_cases [
      {["bob", "blog_post", "read"], true},
      {["bob", "blog_post", "create"], false},
      {["bob", "blog_post", "modify"], false},
      {["bob", "blog_post", "delete"], false},
      {["peter", "blog_post", "read"], false},
      {["peter", "blog_post", "create"], true},
      {["peter", "blog_post", "modify"], true},
      {["peter", "blog_post", "delete"], false},
      {["alice", "blog_post", "read"], false},
      {["alice", "blog_post", "create"], true},
      {["alice", "blog_post", "modify"], true},
      {["alice", "blog_post", "delete"], true}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        e = Enforcer.remove_mapping_policy(e, {:g, "author", "reader"})
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end

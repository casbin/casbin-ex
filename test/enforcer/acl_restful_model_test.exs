defmodule Acx.Enforcer.AclRestfulModelTest do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  @cfile "../data/acl_restful.conf" |> Path.expand(__DIR__)
  @pfile "../data/acl_restful.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)
    e = e |> Enforcer.load_policies!(@pfile)
    {:ok, e: e}
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
      {["alice", "/peter_data/", "GET"], false},
      {["alice", "/peter_data/", "POST"], false},
      {["alice", "/peter_data/foo", "GET"], false},
      {["alice", "/peter_data/foo", "POST"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect(req)}`", %{e: e} do
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
      {["bob", "/peter_data", "GET"], false},
      {["bob", "/peter_data", "POST"], false},
      {["bob", "/peter_data/", "GET"], false},
      {["bob", "/peter_data/", "POST"], false},
      {["bob", "/peter_data/foo", "GET"], false},
      {["bob", "/peter_data/foo", "POST"], false},
      {["bob", "/peter_data/foo/baz", "GET"], false},
      {["bob", "/peter_data/foo/baz", "POST"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect(req)}`", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "allow?/2 when `sub` is `peter`" do
    @test_cases [
      {["peter", "/peter_data", "POST"], true},
      {["peter", "/peter_data", "GET"], true},
      {["peter", "/peter_data/", "POST"], false},
      {["peter", "/peter_data/", "GET"], false},
      {["peter", "/peter_data/foo", "POST"], false},
      {["peter", "/peter_data/foo", "GET"], false},
      {["peter", "/alice_data", "GET"], false},
      {["peter", "/alice_data", "POST"], false},
      {["peter", "/alice_data/", "GET"], false},
      {["peter", "/alice_data/", "POST"], false},
      {["peter", "/alice_data/resource1", "GET"], false},
      {["peter", "/alice_data/resource1", "POST"], false},
      {["peter", "/alice_data/resource2", "GET"], false},
      {["peter", "/alice_data/resource2", "POST"], false},
      {["peter", "/alice_data/foo", "GET"], false},
      {["peter", "/alice_data/foo", "POST"], false},
      {["peter", "/bob_data", "GET"], false},
      {["peter", "/bob_data", "POST"], false},
      {["peter", "/bob_data/", "GET"], false},
      {["peter", "/bob_data/", "POST"], false},
      {["peter", "/bob_data/foo", "GET"], false},
      {["peter", "/bob_data/foo", "POST"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect(req)}`", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end

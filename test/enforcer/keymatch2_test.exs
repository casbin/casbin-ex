defmodule Acx.Enforcer.KeyMatch2Test do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  @cfile "../data/keymatch2.conf" |> Path.expand(__DIR__)
  @pfile "../data/keymatch2.csv" |> Path.expand(__DIR__)

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
      {["alice", "/alice_data/1", "GET"], true},
      {["alice", "/alice_data2/1/using/2", "GET"], true},
      {["alice", "/alice_data2/1/using/2", "POST"], false},
      {["alice", "/alice_data2/1/using/2/admin/", "GET"], false},
      {["alice", "/admin/alice_data2/1/using/2", "GET"], false},
      {["bob", "/admin/alice_data2/1/using/2", "GET"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "key_match2?/2" do
    @test_cases [
      {"/foo", "/foo", true},
      {"/foo", "/foo*", true},
      {"/foo", "/foo/*", false},
      {"/foo/bar", "/foo", false},
      {"/foo/bar", "/foo*", false},
      {"/foo/bar", "/foo/*", true},
      {"/foobar", "/foo", false},
      {"/foobar", "/foo*", false},
      {"/foobar", "/foo/*", false},
      {"/", "/:resource", false},
      {"/resource1", "/:resource", true},
      {"/myid", "/:id/using/:resId", false},
      {"/myid/using/myresid", "/:id/using/:resId", true},
      {"/proxy/myid", "/proxy/:id/*", false},
      {"/proxy/myid/", "/proxy/:id/*", true},
      {"/proxy/myid/res", "/proxy/:id/*", true},
      {"/proxy/myid/res/res2", "/proxy/:id/*", true},
      {"/proxy/myid/res/res2/res3", "/proxy/:id/*", true},
      {"/proxy/", "/proxy/:id/*", false},
      {"/alice", "/:id", true},
      {"/alice/all", "/:id/all", true},
      {"/alice", "/:id/all", false},
      {"/alice/all", "/:id", false},
      {"/alice/all", "/:/all", false}
    ]

    Enum.each(@test_cases, fn {key1, key2, res} ->
      test "response `#{res}` for combination `#{key1}` `#{key2}`" do
        assert Enforcer.key_match2?(unquote(key1), unquote(key2)) === unquote(res)
      end
    end)
  end
end

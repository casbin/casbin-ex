defmodule Acx.Persist.EctoRbacTest do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  @cfile "../data/rbac.conf" |> Path.expand(__DIR__)

  defmodule MockAclRepo do
    use Acx.Persist.MockRepo, pfile: "../data/rbac.csv" |> Path.expand(__DIR__)
  end

  @repo MockAclRepo

  setup do
    adapter = Acx.Persist.EctoAdapter.new(@repo)
    {:ok, e} = Enforcer.init(@cfile, adapter)

    e =
      Enforcer.load_policies!(e)
      |> Enforcer.load_mapping_policies!()

    {:ok, e: e}
  end

  defp setup_delete_author_role(%{e: e} = ctx) do
    e = Enforcer.remove_mapping_policy(e, {:g, "author", "reader"})
    %{ctx | e: e}
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

  describe "when removed mapping policy author -> reader" do
    setup [:setup_delete_author_role]

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
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end

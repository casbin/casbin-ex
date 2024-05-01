defmodule Acx.Persist.EctoAclTest do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  defmodule MockAclRepo do
    use Acx.Persist.MockRepo, pfile: "../data/acl.csv" |> Path.expand(__DIR__)
  end

  @cfile "../data/acl.conf" |> Path.expand(__DIR__)
  @repo MockAclRepo

  setup do
    adapter = Acx.Persist.EctoAdapter.new(@repo)

    {:ok, e} = Enforcer.init(@cfile, adapter)
    e = Enforcer.load_policies!(e)
    {:ok, e: e}
  end

  describe "allow?/2" do
    @test_cases [
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
      {["peter", "blog_post", "foo"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response #{res} for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end

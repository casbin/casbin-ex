defmodule Casbin.Persist.EctoAdapterTest do
  use ExUnit.Case, async: true
  alias Casbin.Persist.EctoAdapter
  alias Casbin.Persist.EctoAdapter.CasbinRule
  alias Casbin.Persist.PersistAdapter
  doctest Casbin.Persist.EctoAdapter
  doctest Casbin.Persist.PersistAdapter.Casbin.Persist.EctoAdapter
  doctest Casbin.Persist.EctoAdapter.CasbinRule

  defmodule MockTestRepo do
    use Casbin.Persist.MockRepo, pfile: "../data/acl.csv" |> Path.expand(__DIR__)
  end

  describe "using the mock repo" do
    @repo MockTestRepo

    test "loads policies from the database" do
      expected =
        {:ok,
         [
           ["p", "alice", "blog_post", "create"],
           ["p", "alice", "blog_post", "delete"],
           ["p", "alice", "blog_post", "modify"],
           ["p", "alice", "blog_post", "read"],
           ["p", "bob", "blog_post", "read"],
           ["p", "peter", "blog_post", "create"],
           ["p", "peter", "blog_post", "modify"],
           ["p", "peter", "blog_post", "read"]
         ]}

      loaded =
        EctoAdapter.new(@repo)
        |> PersistAdapter.load_policies()

      assert loaded === expected
    end
  end
end

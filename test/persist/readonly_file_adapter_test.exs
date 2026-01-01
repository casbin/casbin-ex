defmodule Casbin.Persist.ReadonlyFileAdapterTest do
  use ExUnit.Case, async: true
  alias Casbin.Persist.PersistAdapter
  alias Casbin.Persist.ReadonlyFileAdapter
  doctest Casbin.Persist.ReadonlyFileAdapter

  describe "given a policy file" do
    @pfile "../data/acl.csv" |> Path.expand(__DIR__)

    test "loads all of the policies" do
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
        ReadonlyFileAdapter.new(@pfile)
        |> PersistAdapter.load_policies()

      assert loaded === expected
    end
  end
end

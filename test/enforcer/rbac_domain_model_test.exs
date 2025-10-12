defmodule Acx.Enforcer.RbacDomainModelTest do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  @cfile "../data/rbac_domain.conf" |> Path.expand(__DIR__)
  @pfile "../data/rbac_domain.csv" |> Path.expand(__DIR__)

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
      {["alice", "domain1", "data1", "read"], true},
      {["alice", "domain1", "data1", "write"], true},
      {["alice", "domain2", "data2", "read"], true},
      {["alice", "domain2", "data2", "write"], true},
      {["alice", "domain2", "data2", "no_existing"], false},
      {["alice", "domain2", "no_existing", "read"], false},
      {["alice", "domain3", "data2", "read"], false},
      {["bob", "domain1", "data1", "read"], false},
      {["bob", "domain1", "data1", "write"], false},
      {["bob", "domain2", "data2", "read"], true},
      {["bob", "domain2", "data2", "write"], true},
      {["bob", "domain2", "data2", "no_existing"], false},
      {["bob", "domain2", "no_existing", "read"], false},
      {["bob", "domain3", "data2", "read"], true},
      {["peter", "domain1", "data1", "read"], false},
      {["peter", "domain1", "data1", "write"], false},
      {["peter", "domain2", "data2", "read"], false},
      {["peter", "domain2", "data2", "write"], false},
      {["peter", "domain2", "data2", "no_existing"], false},
      {["peter", "domain2", "no_existing", "read"], false},
      {["peter", "domain3", "data2", "read"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "removed role allow?/2" do
    @test_cases [
      {["alice", "domain1", "data1", "read"], false},
      {["alice", "domain1", "data1", "write"], false},
      {["alice", "domain2", "data2", "read"], true},
      {["alice", "domain2", "data2", "write"], true},
      {["alice", "domain2", "data2", "no_existing"], false},
      {["alice", "domain2", "no_existing", "read"], false},
      {["alice", "domain3", "data2", "read"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        e = Enforcer.remove_mapping_policy(e, {:g, "alice", "admin", "domain1"})
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end

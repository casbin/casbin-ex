defmodule Acx.Enforcer.G3WithDomain do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  @cfile "../data/g3_with_domain.conf" |> Path.expand(__DIR__)
  @pfile "../data/g3_with_domain.csv" |> Path.expand(__DIR__)

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
      {["alice", "1", "/data/organizations/1/", "GET"], true},
      {["alice", "1", "/data/organizations/1/", "POST"], true},
      {["alice", "2", "/data/organizations/2/", "GET"], true},
      {["alice", "2", "/data/organizations/2/", "POST"], true},
      {["alice", "3", "/data/organizations/3/", "GET"], true},
      {["alice", "3", "/data/organizations/3/", "POST"], true},
      {["alice", "1", "/data/organizations/1/", "no_existing"], false},
      {["alice", "1", "no_existing", "GET"], false},
      {["bob", "1", "/data/organizations/1/", "GET"], true},
      {["bob", "1", "/data/organizations/1/", "POST"], true},
      {["bob", "2", "/data/organizations/2/", "GET"], false},
      {["bob", "2", "/data/organizations/2/", "POST"], false},
      {["bob", "3", "/data/organizations/3/", "GET"], false},
      {["bob", "3", "/data/organizations/3/", "POST"], false},
      {["bob", "1", "/data/organizations/1/", "no_existing"], false},
      {["bob", "1", "no_existing", "GET"], false},
      {["peter", "1", "/data/organizations/1/", "GET"], false},
      {["peter", "1", "/data/organizations/1/", "POST"], false},
      {["peter", "2", "/data/organizations/2/", "GET"], true},
      {["peter", "2", "/data/organizations/2/", "POST"], true},
      {["peter", "3", "/data/organizations/3/", "GET"], false},
      {["peter", "3", "/data/organizations/3/", "POST"], false},
      {["peter", "1", "/data/organizations/1/", "no_existing"], false},
      {["peter", "1", "no_existing", "GET"], false},
      {["john", "1", "/data/organizations/1/", "GET"], false},
      {["john", "1", "/data/organizations/1/", "POST"], false},
      {["john", "2", "/data/organizations/2/", "GET"], true},
      {["john", "2", "/data/organizations/2/", "POST"], false},
      {["john", "3", "/data/organizations/3/", "GET"], false},
      {["john", "3", "/data/organizations/3/", "POST"], false},
      {["john", "1", "/data/organizations/1/", "no_existing"], false},
      {["john", "1", "no_existing", "GET"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end

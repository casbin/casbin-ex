defmodule Acx.Enforcer.KeyMatch2Test do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  @cfile "../data/keyMatch2.conf" |> Path.expand(__DIR__)
  @pfile "../data/keyMatch2.csv" |> Path.expand(__DIR__)

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
end

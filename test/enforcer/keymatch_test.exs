defmodule Casbin.Enforcer.KeyMatchTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer

  @cfile "../data/keymatch.conf" |> Path.expand(__DIR__)
  @pfile "../data/keymatch.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)

    e =
      e
      |> Enforcer.load_policies!(@pfile)

    {:ok, e: e}
  end

  describe "allow?/2 with keyMatch" do
    @test_cases [
      {["alice", "/alice_data/resource1", "GET"], true},
      {["alice", "/alice_data", "GET"], true},
      {["alice", "/alice_data/", "POST"], true},
      {["alice", "/alice_data/resource1", "POST"], true},
      {["alice", "/alice_data", "POST"], false},
      {["bob", "/bob_data/resource1", "GET"], true},
      {["bob", "/bob_data/", "GET"], true},
      {["bob", "/alice_data", "GET"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end

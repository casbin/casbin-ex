defmodule Casbin.Persist.FilteredPolicyTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer
  alias Casbin.Persist.EctoAdapter
  alias Casbin.Persist.PersistAdapter

  @cfile "../data/rbac_domain.conf" |> Path.expand(__DIR__)

  describe "load_filtered_policy/2 with EctoAdapter" do
    test "returns error when repo is not set" do
      adapter = EctoAdapter.new(nil)
      assert {:error, "repo is not set"} == PersistAdapter.load_filtered_policy(adapter, %{})
    end
  end

  describe "load_filtered_policies!/2 with Enforcer" do
    test "raises error when repo is not set" do
      adapter = EctoAdapter.new(nil)
      {:ok, e} = Enforcer.init(@cfile, adapter)

      assert_raise ArgumentError, "repo is not set", fn ->
        Enforcer.load_filtered_policies!(e, %{v2: "domain1"})
      end
    end
  end
end

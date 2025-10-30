defmodule Acx.Persist.LoadPoliciesFromAdapterTest do
  use ExUnit.Case, async: true
  alias Acx.Enforcer
  alias Acx.EnforcerServer
  alias Acx.Persist.EctoAdapter

  @cfile "../data/rbac.conf" |> Path.expand(__DIR__)

  defmodule MockRepo do
    use Acx.Persist.MockRepo, pfile: "../data/rbac.csv" |> Path.expand(__DIR__)
  end

  @repo MockRepo
  @enforcer_name :test_load_from_adapter

  setup do
    # Start the enforcer with a model but no policies
    {:ok, _pid} = EnforcerServer.start_link(@enforcer_name, @cfile)

    # Set the persist adapter
    adapter = EctoAdapter.new(@repo)
    :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)

    on_exit(fn ->
      # Clean up the enforcer process if it's still running
      case Process.whereis({:via, Registry, {Acx.EnforcerRegistry, @enforcer_name}}) do
        nil -> :ok
        pid -> Process.exit(pid, :kill)
      end
    end)

    {:ok, adapter: adapter}
  end

  describe "EnforcerServer.load_policies_from_adapter/1" do
    test "loads policies and mapping policies from the adapter" do
      # Before loading, policies should not work
      refute EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "delete"])

      # Load policies from adapter
      :ok = EnforcerServer.load_policies_from_adapter(@enforcer_name)

      # After loading, policies should work
      assert EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "delete"])
      assert EnforcerServer.allow?(@enforcer_name, ["peter", "blog_post", "create"])
      assert EnforcerServer.allow?(@enforcer_name, ["bob", "blog_post", "read"])

      # Check that mapping policies were loaded too (bob has reader role)
      refute EnforcerServer.allow?(@enforcer_name, ["bob", "blog_post", "create"])
    end

    test "lists loaded policies after loading from adapter" do
      # Load policies from adapter
      :ok = EnforcerServer.load_policies_from_adapter(@enforcer_name)

      # Check that policies are present
      policies = EnforcerServer.list_policies(@enforcer_name, %{key: :p})
      assert length(policies) > 0

      # Verify specific policy exists
      alice_delete_policy =
        Enum.find(policies, fn policy ->
          policy.attrs[:sub] == "alice" and
            policy.attrs[:obj] == "blog_post" and
            policy.attrs[:act] == "delete"
        end)

      assert alice_delete_policy != nil
    end

    test "works with enforcer lifecycle (startup simulation)" do
      # Simulate application startup where we:
      # 1. Start enforcer
      # 2. Set adapter
      # 3. Load policies from database

      # Adapter was already set in setup
      # Now load policies as you would on startup
      :ok = EnforcerServer.load_policies_from_adapter(@enforcer_name)

      # Verify that all expected policies work
      test_cases = [
        {["bob", "blog_post", "read"], true},
        {["bob", "blog_post", "create"], false},
        {["peter", "blog_post", "read"], true},
        {["peter", "blog_post", "create"], true},
        {["alice", "blog_post", "delete"], true}
      ]

      Enum.each(test_cases, fn {req, expected} ->
        assert EnforcerServer.allow?(@enforcer_name, req) === expected
      end)
    end
  end

  describe "Enforcer.load_policies!/1 with adapter" do
    test "loads policies from configured adapter" do
      adapter = EctoAdapter.new(@repo)
      {:ok, enforcer} = Enforcer.init(@cfile, adapter)

      # Before loading, no policies
      assert enforcer.policies == []

      # Load policies from adapter
      enforcer = Enforcer.load_policies!(enforcer)

      # After loading, policies exist
      assert length(enforcer.policies) > 0
    end

    test "loads both policies and mapping policies" do
      adapter = EctoAdapter.new(@repo)
      {:ok, enforcer} = Enforcer.init(@cfile, adapter)

      # Load both policies and mapping policies
      enforcer =
        enforcer
        |> Enforcer.load_policies!()
        |> Enforcer.load_mapping_policies!()

      # Verify policies are loaded
      assert length(enforcer.policies) > 0

      # Verify mapping policies are loaded
      assert length(enforcer.mapping_policies) > 0

      # Test that role-based access works
      assert Enforcer.allow?(enforcer, ["alice", "blog_post", "delete"])
      assert Enforcer.allow?(enforcer, ["bob", "blog_post", "read"])
      refute Enforcer.allow?(enforcer, ["bob", "blog_post", "create"])
    end
  end
end

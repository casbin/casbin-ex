defmodule Acx.EnforcerServerAdapterTest do
  use ExUnit.Case, async: true
  alias Acx.{EnforcerSupervisor, EnforcerServer}
  alias Acx.Persist.EctoAdapter

  @cfile "../test/data/rbac.conf" |> Path.expand(__DIR__)

  defmodule MockRbacRepo do
    use Acx.Persist.MockRepo, pfile: "../test/data/rbac.csv" |> Path.expand(__DIR__)
  end

  @repo MockRbacRepo

  setup do
    ename = "test_enforcer_#{:erlang.unique_integer([:positive])}"
    EnforcerSupervisor.start_enforcer(ename, @cfile)

    on_exit(fn ->
      try do
        GenServer.stop(via_tuple(ename))
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, ename: ename}
  end

  defp via_tuple(ename) do
    {:via, Registry, {Acx.EnforcerRegistry, ename}}
  end

  describe "load_policies/1 with EctoAdapter" do
    test "loads policies from database adapter on startup", %{ename: ename} do
      # Set up the adapter
      adapter = EctoAdapter.new(@repo)
      :ok = EnforcerServer.set_persist_adapter(ename, adapter)

      # Load policies from the adapter (no file path needed)
      :ok = EnforcerServer.load_policies(ename)

      # Verify policies are loaded by checking authorization
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) === false
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === false

      # Now load mapping policies to complete the RBAC setup
      :ok = EnforcerServer.load_mapping_policies(ename)

      # Verify RBAC is working correctly
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "create"]) === false
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "delete"]) === true
    end

    test "policies persist across adapter operations", %{ename: ename} do
      # Set up the adapter
      adapter = EctoAdapter.new(@repo)
      :ok = EnforcerServer.set_persist_adapter(ename, adapter)

      # Load initial policies and mappings
      :ok = EnforcerServer.load_policies(ename)
      :ok = EnforcerServer.load_mapping_policies(ename)

      # Add a new policy (should be saved to adapter)
      :ok = EnforcerServer.add_policy(ename, {:p, ["guest", "blog_post", "read"]})

      # Verify the new policy works
      assert EnforcerServer.allow?(ename, ["guest", "blog_post", "read"]) === true

      # List policies to verify it was added
      policies = EnforcerServer.list_policies(ename, %{sub: "guest"})
      assert length(policies) === 1
      assert hd(policies).key === :p
    end
  end

  describe "load_mapping_policies/1 with EctoAdapter" do
    test "loads mapping policies from database adapter", %{ename: ename} do
      # Set up the adapter
      adapter = EctoAdapter.new(@repo)
      :ok = EnforcerServer.set_persist_adapter(ename, adapter)

      # Load policies first
      :ok = EnforcerServer.load_policies(ename)

      # Then load mapping policies from adapter
      :ok = EnforcerServer.load_mapping_policies(ename)

      # Verify role inheritance is working
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) === true
    end

    test "works without loading policies first", %{ename: ename} do
      # Set up the adapter
      adapter = EctoAdapter.new(@repo)
      :ok = EnforcerServer.set_persist_adapter(ename, adapter)

      # Load only mapping policies
      :ok = EnforcerServer.load_mapping_policies(ename)

      # Mappings should be loaded (though without policies they won't grant access)
      # Just verify the function doesn't crash
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === false
    end
  end

  describe "backward compatibility" do
    test "load_policies/2 still works with file path", %{ename: ename} do
      pfile = "../test/data/acl.csv" |> Path.expand(__DIR__)

      # Load policies from file (old behavior)
      :ok = EnforcerServer.load_policies(ename, pfile)

      # Verify policies are loaded
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) === true
    end

    test "load_mapping_policies/2 still works with file path", %{ename: ename} do
      pfile = "../test/data/rbac.csv" |> Path.expand(__DIR__)

      # Load policies and mappings from file (old behavior)
      :ok = EnforcerServer.load_policies(ename, pfile)
      :ok = EnforcerServer.load_mapping_policies(ename, pfile)

      # Verify RBAC works
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === true
    end
  end
end

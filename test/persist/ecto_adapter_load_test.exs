defmodule Acx.Persist.EctoAdapterLoadTest do
  use ExUnit.Case, async: false
  alias Acx.EnforcerServer
  alias Acx.Enforcer
  alias Acx.Persist.EctoAdapter

  defmodule MockAclRepo do
    use Acx.Persist.MockRepo, pfile: "../data/acl.csv" |> Path.expand(__DIR__)
  end

  defmodule MockRbacRepo do
    use Acx.Persist.MockRepo, pfile: "../data/rbac.csv" |> Path.expand(__DIR__)
  end

  @acl_cfile "../data/acl.conf" |> Path.expand(__DIR__)
  @rbac_cfile "../data/rbac.conf" |> Path.expand(__DIR__)

  describe "load_policies_from_adapter/1 for ACL model" do
    setup do
      # Start a fresh enforcer for each test
      enforcer_name = :"test_enforcer_#{:erlang.unique_integer([:positive])}"
      {:ok, _pid} = EnforcerServer.start_link(enforcer_name, @acl_cfile)

      on_exit(fn ->
        case Process.whereis({:via, Registry, {Acx.EnforcerRegistry, enforcer_name}}) do
          nil -> :ok
          pid -> Process.exit(pid, :kill)
        end
      end)

      {:ok, enforcer_name: enforcer_name}
    end

    test "loads policies from adapter into memory", %{enforcer_name: enforcer_name} do
      # Set the persist adapter
      adapter = EctoAdapter.new(MockAclRepo)
      :ok = EnforcerServer.set_persist_adapter(enforcer_name, adapter)

      # Load policies from the adapter
      :ok = EnforcerServer.load_policies_from_adapter(enforcer_name)

      # Verify that policies are loaded into memory by checking permissions
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["bob", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["bob", "blog_post", "create"]) === false
      assert EnforcerServer.allow?(enforcer_name, ["peter", "blog_post", "modify"]) === true
    end

    test "returns error when adapter is not set", %{enforcer_name: enforcer_name} do
      # Try to load without setting an adapter
      result = EnforcerServer.load_policies_from_adapter(enforcer_name)
      assert result === {:error, "No adapter set and no policy file provided"}
    end

    test "policies are available after restart simulation", %{enforcer_name: enforcer_name} do
      # Simulate the issue scenario: configure adapter, add policy, restart
      adapter = EctoAdapter.new(MockAclRepo)
      :ok = EnforcerServer.set_persist_adapter(enforcer_name, adapter)

      # Load policies from adapter (simulating startup after restart)
      :ok = EnforcerServer.load_policies_from_adapter(enforcer_name)

      # Verify the loaded policies work
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "delete"]) === true
    end
  end

  describe "load_policies_from_adapter/1 for RBAC model" do
    setup do
      # Start a fresh enforcer for each test
      enforcer_name = :"test_enforcer_rbac_#{:erlang.unique_integer([:positive])}"
      {:ok, _pid} = EnforcerServer.start_link(enforcer_name, @rbac_cfile)

      on_exit(fn ->
        case Process.whereis({:via, Registry, {Acx.EnforcerRegistry, enforcer_name}}) do
          nil -> :ok
          pid -> Process.exit(pid, :kill)
        end
      end)

      {:ok, enforcer_name: enforcer_name}
    end

    test "loads both policies and mapping policies from adapter", %{enforcer_name: enforcer_name} do
      # Set the persist adapter
      adapter = EctoAdapter.new(MockRbacRepo)
      :ok = EnforcerServer.set_persist_adapter(enforcer_name, adapter)

      # Load policies and mapping policies from the adapter
      :ok = EnforcerServer.load_policies_from_adapter(enforcer_name)

      # Verify that policies are loaded
      assert EnforcerServer.allow?(enforcer_name, ["bob", "blog_post", "read"]) === true

      # Verify that role mappings are loaded (bob has reader role, which has read permission)
      # peter is author who inherits from reader
      assert EnforcerServer.allow?(enforcer_name, ["peter", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["peter", "blog_post", "create"]) === true

      # alice is admin who inherits from author (and reader through author)
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "delete"]) === true
    end
  end

  describe "Enforcer.load_policies!/1 (direct usage)" do
    test "loads policies from adapter directly on Enforcer struct" do
      adapter = EctoAdapter.new(MockAclRepo)
      {:ok, e} = Enforcer.init(@acl_cfile, adapter)

      # Load policies using the adapter
      e = Enforcer.load_policies!(e)

      # Verify policies are loaded
      assert Enforcer.allow?(e, ["alice", "blog_post", "read"]) === true
      assert Enforcer.allow?(e, ["bob", "blog_post", "create"]) === false
    end

    test "returns error when no adapter is set" do
      {:ok, e} = Enforcer.init(@acl_cfile)

      # Try to load without an adapter
      result = Enforcer.load_policies!(e)
      assert result === {:error, "No adapter set and no policy file provided"}
    end
  end
end

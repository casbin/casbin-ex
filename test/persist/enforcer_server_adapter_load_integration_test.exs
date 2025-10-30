defmodule Acx.Persist.EnforcerServerAdapterLoadIntegrationTest do
  @moduledoc """
  Integration test that demonstrates the exact use case from the GitHub issue:
  Loading policies from the database on application startup.
  """
  use ExUnit.Case, async: false
  alias Acx.EnforcerServer
  alias Acx.Persist.EctoAdapter

  defmodule MockRepo do
    use Acx.Persist.MockRepo, pfile: "../data/rbac.csv" |> Path.expand(__DIR__)

    # Add transaction support for save_policies if needed
    def transaction(fun) do
      {:ok, fun.()}
    end
  end

  @cfile "../data/rbac.conf" |> Path.expand(__DIR__)

  describe "Issue scenario: Load policies from database on startup" do
    test "demonstrates the complete workflow from the issue" do
      # Step 1: Start a new enforcer (simulating application startup)
      enforcer_name = :my_enforcer
      {:ok, _pid} = EnforcerServer.start_link(enforcer_name, @cfile)

      on_exit(fn ->
        Process.exit(
          Process.whereis({:via, Registry, {Acx.EnforcerRegistry, enforcer_name}}),
          :kill
        )
      end)

      # Step 2: Configure the adapter
      adapter = EctoAdapter.new(MockRepo)
      :ok = EnforcerServer.set_persist_adapter(enforcer_name, adapter)

      # Step 3: Load policies from the database (NEW FUNCTIONALITY)
      # This is what was missing before - a clean way to load policies
      :ok = EnforcerServer.load_policies_from_adapter(enforcer_name)

      # Step 4: Verify policies are loaded and working
      # Admin has delete permission (from the database)
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "delete"]) === true

      # Author has create and modify permissions (from the database)
      assert EnforcerServer.allow?(enforcer_name, ["peter", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["peter", "blog_post", "modify"]) === true

      # Reader has read permission (from the database)
      assert EnforcerServer.allow?(enforcer_name, ["bob", "blog_post", "read"]) === true

      # Negative test: bob (reader) should not have create permission
      assert EnforcerServer.allow?(enforcer_name, ["bob", "blog_post", "create"]) === false
    end

    test "demonstrates the issue scenario - before and after" do
      enforcer_name = :my_enforcer_2
      {:ok, _pid} = EnforcerServer.start_link(enforcer_name, @cfile)

      on_exit(fn ->
        Process.exit(
          Process.whereis({:via, Registry, {Acx.EnforcerRegistry, enforcer_name}}),
          :kill
        )
      end)

      # BEFORE: Without load_policies_from_adapter
      # Configure adapter
      adapter = EctoAdapter.new(MockRepo)
      :ok = EnforcerServer.set_persist_adapter(enforcer_name, adapter)

      # At this point, policies are NOT loaded
      # The allow? call will return false because policies are not in memory
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "delete"]) === false

      # AFTER: With load_policies_from_adapter
      # Now load policies from the adapter
      :ok = EnforcerServer.load_policies_from_adapter(enforcer_name)

      # Now the policies ARE loaded and the allow? call returns the correct result
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "delete"]) === true
    end

    test "simulates application restart scenario" do
      # Scenario: Application starts up, needs to load policies from DB

      # Application startup: Create enforcer
      enforcer_name = :my_enforcer_restart
      {:ok, _pid} = EnforcerServer.start_link(enforcer_name, @cfile)

      on_exit(fn ->
        Process.exit(
          Process.whereis({:via, Registry, {Acx.EnforcerRegistry, enforcer_name}}),
          :kill
        )
      end)

      # Application startup: Configure persistence
      adapter = EctoAdapter.new(MockRepo)
      :ok = EnforcerServer.set_persist_adapter(enforcer_name, adapter)

      # Application startup: Load policies from database
      # This is the NEW, clean way to load policies on startup
      :ok = EnforcerServer.load_policies_from_adapter(enforcer_name)

      # Application is ready to use
      # Verify the enforcer has the policies from the database
      policies = EnforcerServer.list_policies(enforcer_name, %{key: :p})
      assert length(policies) > 0

      # Verify role mappings are also loaded
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(enforcer_name, ["alice", "blog_post", "delete"]) === true
    end
  end
end

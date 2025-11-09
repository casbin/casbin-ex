defmodule Acx.EnforcerServerLoadFromAdapterTest do
  use ExUnit.Case, async: true
  alias Acx.EnforcerServer
  alias Acx.Persist.EctoAdapter

  @enforcer_name "test_enforcer_load_from_adapter"
  @model_file "../data/rbac.conf" |> Path.expand(__DIR__)
  @policy_file "../data/acl.csv" |> Path.expand(__DIR__)

  defmodule MockTestRepo do
    use Acx.Persist.MockRepo, pfile: "../data/acl.csv" |> Path.expand(__DIR__)
  end

  defmodule MockRbacRepo do
    use Acx.Persist.MockRepo, pfile: "../data/rbac.csv" |> Path.expand(__DIR__)
  end

  setup do
    # Start the enforcer with just the model
    {:ok, _pid} = EnforcerServer.start_link(@enforcer_name, @model_file)

    # Clean up after the test
    on_exit(fn ->
      # The enforcer process will be terminated automatically
      # Remove from ETS table if needed
      try do
        GenServer.stop(
          {:via, Registry, {Acx.EnforcerRegistry, @enforcer_name}},
          :normal,
          100
        )
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  describe "load_policies_from_adapter/1" do
    test "loads policies from EctoAdapter into enforcer memory" do
      # Configure adapter
      adapter = EctoAdapter.new(MockTestRepo)
      :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)

      # Load policies from adapter
      :ok = EnforcerServer.load_policies_from_adapter(@enforcer_name)

      # Verify policies are loaded into memory
      assert EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "read"])
      assert EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "create"])
      assert EnforcerServer.allow?(@enforcer_name, ["bob", "blog_post", "read"])
      refute EnforcerServer.allow?(@enforcer_name, ["bob", "blog_post", "create"])
    end

    test "policies persist in memory after application restart simulation" do
      # Initial setup - configure adapter and load policies
      adapter = EctoAdapter.new(MockTestRepo)
      :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)
      :ok = EnforcerServer.load_policies_from_adapter(@enforcer_name)

      # Verify initial state
      assert EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "read"])

      # Add a new policy (should be persisted to "database")
      :ok = EnforcerServer.add_policy(@enforcer_name, {:p, ["charlie", "blog_post", "read"]})

      # Verify new policy works
      assert EnforcerServer.allow?(@enforcer_name, ["charlie", "blog_post", "read"])
    end

    test "works with empty adapter" do
      # Create a mock repo with an empty file
      empty_file = "/tmp/empty_policies.csv"
      File.write!(empty_file, "")

      defmodule EmptyMockRepo do
        use Acx.Persist.MockRepo, pfile: "/tmp/empty_policies.csv"
      end

      adapter = EctoAdapter.new(EmptyMockRepo)
      :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)

      # Should not raise error
      :ok = EnforcerServer.load_policies_from_adapter(@enforcer_name)

      # No policies should be loaded
      refute EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "read"])

      # Clean up
      File.rm(empty_file)
    end
  end

  describe "load_mapping_policies_from_adapter/1" do
    test "loads role mappings from EctoAdapter into enforcer memory" do
      # Configure adapter with RBAC policies
      adapter = EctoAdapter.new(MockRbacRepo)
      :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)

      # Load both policies and mapping policies
      :ok = EnforcerServer.load_policies_from_adapter(@enforcer_name)
      :ok = EnforcerServer.load_mapping_policies_from_adapter(@enforcer_name)

      # Verify role-based access works
      # bob is reader (via role mapping in rbac.csv)
      assert EnforcerServer.allow?(@enforcer_name, ["bob", "blog_post", "read"])

      # alice is admin (via role mapping in rbac.csv)
      assert EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "write"])
      assert EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "read"])
    end
  end

  describe "integration with load_filtered_policies/2" do
    test "can use filtered loading after setting adapter" do
      adapter = EctoAdapter.new(MockTestRepo)
      :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)

      # Load only policies for alice (filter by subject)
      :ok = EnforcerServer.load_filtered_policies(@enforcer_name, %{v0: "alice"})

      # alice's policies should be loaded
      assert EnforcerServer.allow?(@enforcer_name, ["alice", "blog_post", "read"])

      # bob's policies should NOT be loaded (filtered out)
      refute EnforcerServer.allow?(@enforcer_name, ["bob", "blog_post", "read"])
    end
  end
end

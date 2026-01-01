defmodule Casbin.AsyncTestingExampleTest do
  @moduledoc """
  This test module demonstrates how to write async tests with Casbin
  using the TestHelper module for enforcer isolation.

  Each test gets its own unique enforcer instance, allowing tests to run
  in parallel without race conditions.
  """
  use ExUnit.Case, async: true

  import Casbin.TestHelper

  alias Casbin.EnforcerServer

  @cfile "../data/acl.conf" |> Path.expand(__DIR__)

  setup do
    # Create a unique enforcer for this test
    enforcer_name = unique_enforcer_name("async_test")

    {:ok, _pid} = start_test_enforcer(enforcer_name, @cfile)

    # Clean up after the test
    on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)

    {:ok, enforcer_name: enforcer_name}
  end

  describe "isolated enforcers in async tests" do
    test "alice can read and write", %{enforcer_name: name} do
      # Add policies for alice
      :ok = EnforcerServer.add_policy(name, {:p, ["alice", "data1", "read"]})
      :ok = EnforcerServer.add_policy(name, {:p, ["alice", "data1", "write"]})

      # Verify permissions
      assert EnforcerServer.allow?(name, ["alice", "data1", "read"])
      assert EnforcerServer.allow?(name, ["alice", "data1", "write"])
      refute EnforcerServer.allow?(name, ["alice", "data1", "delete"])

      # List alice's policies
      policies = EnforcerServer.list_policies(name, %{sub: "alice"})
      assert length(policies) == 2
    end

    test "bob has limited access", %{enforcer_name: name} do
      # Add policy for bob
      :ok = EnforcerServer.add_policy(name, {:p, ["bob", "data2", "read"]})

      # Verify permissions
      assert EnforcerServer.allow?(name, ["bob", "data2", "read"])
      refute EnforcerServer.allow?(name, ["bob", "data2", "write"])
      refute EnforcerServer.allow?(name, ["bob", "data2", "delete"])

      # Bob shouldn't have access to data1
      refute EnforcerServer.allow?(name, ["bob", "data1", "read"])
    end

    test "can remove policies", %{enforcer_name: name} do
      # Add a policy
      :ok = EnforcerServer.add_policy(name, {:p, ["charlie", "data3", "read"]})
      assert EnforcerServer.allow?(name, ["charlie", "data3", "read"])

      # Remove the policy
      :ok = EnforcerServer.remove_policy(name, {:p, ["charlie", "data3", "read"]})
      refute EnforcerServer.allow?(name, ["charlie", "data3", "read"])

      # Verify it's gone
      policies = EnforcerServer.list_policies(name, %{sub: "charlie"})
      assert policies == []
    end

    test "multiple policies for same subject", %{enforcer_name: name} do
      # Add multiple policies for dave
      :ok = EnforcerServer.add_policy(name, {:p, ["dave", "data4", "read"]})
      :ok = EnforcerServer.add_policy(name, {:p, ["dave", "data4", "write"]})
      :ok = EnforcerServer.add_policy(name, {:p, ["dave", "data5", "read"]})

      # Verify all permissions
      assert EnforcerServer.allow?(name, ["dave", "data4", "read"])
      assert EnforcerServer.allow?(name, ["dave", "data4", "write"])
      assert EnforcerServer.allow?(name, ["dave", "data5", "read"])

      # Dave shouldn't have delete permission
      refute EnforcerServer.allow?(name, ["dave", "data4", "delete"])

      # List all dave's policies
      policies = EnforcerServer.list_policies(name, %{sub: "dave"})
      assert length(policies) == 3
    end

    test "policies are isolated between tests", %{enforcer_name: name} do
      # This test should start with an empty policy set
      # Previous tests' policies should not be visible here
      policies = EnforcerServer.list_policies(name, %{})
      assert policies == []

      # Add a policy specific to this test
      :ok = EnforcerServer.add_policy(name, {:p, ["eve", "data6", "read"]})

      # Only eve's policy should be present
      all_policies = EnforcerServer.list_policies(name, %{})
      assert length(all_policies) == 1
      assert EnforcerServer.allow?(name, ["eve", "data6", "read"])

      # Other users from other tests shouldn't exist
      refute EnforcerServer.allow?(name, ["alice", "data1", "read"])
      refute EnforcerServer.allow?(name, ["bob", "data2", "read"])
    end
  end

  describe "with initial policies loaded" do
    setup %{enforcer_name: name} do
      # Load some initial policies for all tests in this describe block
      :ok = EnforcerServer.add_policy(name, {:p, ["admin", "data1", "read"]})
      :ok = EnforcerServer.add_policy(name, {:p, ["admin", "data1", "write"]})
      :ok = EnforcerServer.add_policy(name, {:p, ["admin", "data1", "delete"]})

      :ok
    end

    test "admin has full access", %{enforcer_name: name} do
      assert EnforcerServer.allow?(name, ["admin", "data1", "read"])
      assert EnforcerServer.allow?(name, ["admin", "data1", "write"])
      assert EnforcerServer.allow?(name, ["admin", "data1", "delete"])
    end

    test "can add more policies on top of initial ones", %{enforcer_name: name} do
      # Initial admin policies should be present
      assert EnforcerServer.allow?(name, ["admin", "data1", "read"])

      # Add a new user
      :ok = EnforcerServer.add_policy(name, {:p, ["user", "data2", "read"]})
      assert EnforcerServer.allow?(name, ["user", "data2", "read"])

      # Both should coexist
      policies = EnforcerServer.list_policies(name, %{})
      assert length(policies) == 4
    end
  end

  describe "error handling" do
    test "adding duplicate policy returns error", %{enforcer_name: name} do
      # Add a policy
      :ok = EnforcerServer.add_policy(name, {:p, ["frank", "data7", "read"]})

      # Try to add the same policy again
      result = EnforcerServer.add_policy(name, {:p, ["frank", "data7", "read"]})
      assert {:error, :already_existed} = result
    end

    test "removing non-existent policy returns error", %{enforcer_name: name} do
      # Try to remove a policy that doesn't exist
      result = EnforcerServer.remove_policy(name, {:p, ["ghost", "data99", "read"]})
      assert {:error, :not_found} = result
    end
  end

  describe "resetting enforcer state" do
    test "can reset to clean state", %{enforcer_name: name} do
      # Add some policies
      :ok = EnforcerServer.add_policy(name, {:p, ["george", "data8", "read"]})
      :ok = EnforcerServer.add_policy(name, {:p, ["george", "data8", "write"]})

      # Verify they exist
      policies = EnforcerServer.list_policies(name, %{})
      assert length(policies) == 2

      # Reset the enforcer
      :ok = reset_test_enforcer(name, @cfile)

      # Policies should be gone
      policies_after_reset = EnforcerServer.list_policies(name, %{})
      assert policies_after_reset == []

      # Should be able to add new policies
      :ok = EnforcerServer.add_policy(name, {:p, ["henry", "data9", "read"]})
      assert EnforcerServer.allow?(name, ["henry", "data9", "read"])
    end
  end
end

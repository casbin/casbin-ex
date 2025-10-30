defmodule Acx.EnforcerAsyncTest do
  @moduledoc """
  Tests to validate that async tests work properly with isolated enforcers.
  """
  use ExUnit.Case, async: true
  import Acx.EnforcerTestHelper

  alias Acx.EnforcerServer

  @cfile "../data/acl.conf" |> Path.expand(__DIR__)

  describe "isolated enforcers with async: true" do
    setup do
      {:ok, ename, _pid} = start_test_enforcer("async_test", @cfile)
      {:ok, ename: ename}
    end

    test "can add and check policies without interference - test 1", %{ename: ename} do
      # Add a policy specific to this test
      :ok = EnforcerServer.add_policy(ename, {:p, ["user1", "resource1", "read"]})

      # Should be allowed
      assert EnforcerServer.allow?(ename, ["user1", "resource1", "read"])

      # Should not be allowed
      refute EnforcerServer.allow?(ename, ["user1", "resource1", "write"])
    end

    test "can add and check policies without interference - test 2", %{ename: ename} do
      # Add a different policy specific to this test
      :ok = EnforcerServer.add_policy(ename, {:p, ["user2", "resource2", "write"]})

      # Should be allowed
      assert EnforcerServer.allow?(ename, ["user2", "resource2", "write"])

      # Should not be allowed (different from test 1)
      refute EnforcerServer.allow?(ename, ["user1", "resource1", "read"])
    end

    test "can add and check policies without interference - test 3", %{ename: ename} do
      # Add yet another policy specific to this test
      :ok = EnforcerServer.add_policy(ename, {:p, ["user3", "resource3", "delete"]})

      # Should be allowed
      assert EnforcerServer.allow?(ename, ["user3", "resource3", "delete"])

      # Should not be allowed (different from tests 1 and 2)
      refute EnforcerServer.allow?(ename, ["user1", "resource1", "read"])
      refute EnforcerServer.allow?(ename, ["user2", "resource2", "write"])
    end

    test "list_policies returns only policies from this test", %{ename: ename} do
      # Add policies
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data1", "read"]})
      :ok = EnforcerServer.add_policy(ename, {:p, ["bob", "data2", "write"]})

      # List policies
      policies = EnforcerServer.list_policies(ename, %{})

      # Should only have the policies we just added (not from other tests)
      assert length(policies) == 2
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "alice" end)
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "bob" end)
    end

    test "removing policies only affects this test", %{ename: ename} do
      # Add and then remove a policy
      :ok = EnforcerServer.add_policy(ename, {:p, ["temp_user", "temp_resource", "read"]})
      assert EnforcerServer.allow?(ename, ["temp_user", "temp_resource", "read"])

      :ok = EnforcerServer.remove_policy(ename, {:p, ["temp_user", "temp_resource", "read"]})
      refute EnforcerServer.allow?(ename, ["temp_user", "temp_resource", "read"])

      # Verify it's actually gone
      policies = EnforcerServer.list_policies(ename, %{})
      assert length(policies) == 0
    end
  end

  describe "unique_enforcer_name/1" do
    test "generates unique names" do
      name1 = unique_enforcer_name("test")
      name2 = unique_enforcer_name("test")

      assert name1 != name2
      assert String.starts_with?(name1, "test_")
      assert String.starts_with?(name2, "test_")
    end
  end

  describe "manual enforcer management" do
    test "can manually start and stop isolated enforcer" do
      ename = unique_enforcer_name("manual_test")
      {:ok, pid} = EnforcerServer.start_link_isolated(ename, @cfile)

      assert Process.alive?(pid)

      # Use the enforcer
      :ok = EnforcerServer.add_policy(ename, {:p, ["user", "resource", "action"]})
      assert EnforcerServer.allow?(ename, ["user", "resource", "action"])

      # Stop it
      stop_enforcer(ename)

      # Verify it's stopped (this might take a moment)
      Process.sleep(100)
      refute Process.alive?(pid)
    end
  end
end

defmodule AsyncTestExample do
  @moduledoc """
  Example demonstrating async test patterns with isolated enforcers.

  This example shows how to use the new isolation features to write
  async tests without race conditions.
  """

  use ExUnit.Case, async: true
  import Acx.EnforcerTestHelper

  @cfile "test/data/acl.conf" |> Path.expand(__DIR__)

  describe "Example: Using isolated enforcers in async tests" do
    setup do
      # Each test gets its own isolated enforcer with a unique name
      {:ok, ename, _pid} = start_test_enforcer("example", @cfile)
      {:ok, ename: ename}
    end

    test "test A can add its own policies", %{ename: ename} do
      # This test's policies won't interfere with test B
      Acx.EnforcerServer.add_policy(ename, {:p, ["alice", "resource_a", "read"]})
      assert Acx.EnforcerServer.allow?(ename, ["alice", "resource_a", "read"])
    end

    test "test B can add different policies", %{ename: ename} do
      # This test's policies won't interfere with test A
      Acx.EnforcerServer.add_policy(ename, {:p, ["bob", "resource_b", "write"]})
      assert Acx.EnforcerServer.allow?(ename, ["bob", "resource_b", "write"])
      
      # Test B doesn't see test A's policies
      refute Acx.EnforcerServer.allow?(ename, ["alice", "resource_a", "read"])
    end
  end

  describe "Example: Manual enforcer management" do
    test "creating and destroying enforcers manually" do
      # Generate a unique name
      ename = Acx.EnforcerServer.unique_name("manual_example")
      
      # Start isolated enforcer
      {:ok, pid} = Acx.EnforcerServer.start_link_isolated(ename, @cfile)
      
      # Use the enforcer
      Acx.EnforcerServer.add_policy(ename, {:p, ["charlie", "data", "delete"]})
      assert Acx.EnforcerServer.allow?(ename, ["charlie", "data", "delete"])
      
      # Clean up
      Acx.EnforcerTestHelper.stop_enforcer(ename)
      
      # Verify it's stopped
      Process.sleep(50)
      refute Process.alive?(pid)
    end
  end

  describe "Example: Comparison with old approach" do
    @tag :skip  # Skip because this would fail with async: true
    test "OLD APPROACH: shared enforcer (would fail in async)" do
      # This is how tests USED to be written:
      # All tests use the same enforcer name, causing race conditions
      Acx.EnforcerServer.start_link("shared_enforcer", @cfile)
      
      # If multiple async tests do this, they interfere with each other!
      Acx.EnforcerServer.add_policy("shared_enforcer", {:p, ["user", "data", "read"]})
      assert Acx.EnforcerServer.allow?("shared_enforcer", ["user", "data", "read"])
    end

    test "NEW APPROACH: isolated enforcer (works with async)" do
      # Each test gets its own enforcer with a unique name
      {:ok, ename, _pid} = start_test_enforcer("new_approach", @cfile)
      
      # No race conditions, even with async: true!
      Acx.EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
      assert Acx.EnforcerServer.allow?(ename, ["user", "data", "read"])
    end
  end
end

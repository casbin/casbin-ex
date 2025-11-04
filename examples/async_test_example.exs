# Example: Writing async-safe tests with Acx.TestHelper
#
# This example demonstrates how to write tests that can run in parallel
# without interfering with each other.

defmodule MyApp.PolicyTest do
  use ExUnit.Case, async: true
  import Acx.TestHelper

  alias Acx.EnforcerServer

  @cfile "../test/data/acl.conf" |> Path.expand(__DIR__)

  # Setup: Each test gets its own unique enforcer
  setup do
    # This creates a unique enforcer for this test
    # and automatically cleans it up when the test completes
    setup_enforcer(@cfile)
  end

  test "admin can create blog posts", %{enforcer_name: ename} do
    # Add a policy specific to this test
    :ok = EnforcerServer.add_policy(ename, {:p, ["admin", "blog_post", "create"]})

    # Verify the policy
    assert EnforcerServer.allow?(ename, ["admin", "blog_post", "create"])
    refute EnforcerServer.allow?(ename, ["admin", "blog_post", "delete"])
  end

  test "user can read blog posts", %{enforcer_name: ename} do
    # This test is completely isolated from the "admin" test above
    # It has its own enforcer with no policies yet
    :ok = EnforcerServer.add_policy(ename, {:p, ["user", "blog_post", "read"]})

    assert EnforcerServer.allow?(ename, ["user", "blog_post", "read"])
    refute EnforcerServer.allow?(ename, ["user", "blog_post", "write"])
  end

  test "policies are isolated between tests", %{enforcer_name: ename} do
    # This test starts with a clean slate
    # It doesn't see policies from other tests
    policies = EnforcerServer.list_policies(ename, %{})
    assert policies == []

    # Add some policies
    :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data1", "read"]})
    :ok = EnforcerServer.add_policy(ename, {:p, ["bob", "data2", "write"]})

    # Verify they exist
    policies = EnforcerServer.list_policies(ename, %{})
    assert length(policies) == 2
  end
end

# Example with custom prefix for better debugging
defmodule MyApp.RbacTest do
  use ExUnit.Case, async: true
  import Acx.TestHelper

  alias Acx.EnforcerServer

  @cfile "../test/data/rbac.conf" |> Path.expand(__DIR__)

  setup do
    # Use a custom prefix to identify these tests in logs
    setup_enforcer("rbac_test", @cfile)
  end

  test "role inheritance works", %{enforcer_name: ename} do
    # The enforcer name will be something like "rbac_test_12345"
    # which makes it easy to identify in logs

    # Add role mapping
    :ok = EnforcerServer.add_mapping_policy(ename, {:g, "alice", "admin"})

    # Add policy for admin role
    :ok = EnforcerServer.add_policy(ename, {:p, ["admin", "data", "write"]})

    # Alice should inherit admin permissions
    assert EnforcerServer.allow?(ename, ["alice", "data", "write"])
  end
end

# Example with manual setup for more control
defmodule MyApp.CustomSetupTest do
  use ExUnit.Case, async: true
  import Acx.TestHelper

  alias Acx.{EnforcerServer, EnforcerSupervisor}

  @cfile "../test/data/acl.conf" |> Path.expand(__DIR__)
  @pfile "../test/data/acl.csv" |> Path.expand(__DIR__)

  setup do
    # Manual setup gives you more control
    ename = unique_enforcer_name("custom")

    {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)

    # Load initial policies
    EnforcerServer.load_policies(ename, @pfile)

    # Register cleanup
    on_exit(fn -> cleanup_enforcer(ename) end)

    {:ok, enforcer_name: ename}
  end

  test "works with pre-loaded policies", %{enforcer_name: ename} do
    # The enforcer already has policies from acl.csv
    policies = EnforcerServer.list_policies(ename, %{})
    assert length(policies) > 0
  end
end

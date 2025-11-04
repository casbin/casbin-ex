# Testing with Async Tests

This guide explains how to write async-safe tests when using Casbin-Ex enforcers.

## The Problem with Shared State

When using `EnforcerServer` with a fixed enforcer name (e.g., `"my_enforcer"`), all tests that reference that name will share the same enforcer instance. This creates race conditions when using `async: true`:

```elixir
defmodule MyApp.PolicyTest do
  use ExUnit.Case, async: true  # ❌ This will cause issues!
  
  @enforcer_name "my_enforcer"  # Shared across all tests
  
  setup do
    # This enforcer is shared by ALL tests
    Acx.EnforcerSupervisor.start_enforcer(@enforcer_name, "config.conf")
    :ok
  end
  
  test "admin permissions" do
    Acx.EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "data", "write"]})
    # Another test's cleanup might delete this policy mid-test!
    assert Acx.EnforcerServer.allow?(@enforcer_name, ["admin", "data", "write"])
  end
end
```

**Symptoms of this problem:**
- `list_policies/2` returns `[]` even after adding policies
- `add_policy/2` returns `{:error, :already_existed}` but policies aren't visible
- Tests pass individually but fail when run together
- Tests fail non-deterministically

## Solution 1: Use Acx.TestHelper (Recommended)

The `Acx.TestHelper` module provides utilities to create isolated enforcer instances for each test:

```elixir
defmodule MyApp.PolicyTest do
  use ExUnit.Case, async: true  # ✅ Safe with isolated enforcers
  import Acx.TestHelper
  
  setup do
    # Each test gets its own unique enforcer
    setup_enforcer("path/to/config.conf")
  end
  
  test "admin permissions", %{enforcer_name: ename} do
    Acx.EnforcerServer.add_policy(ename, {:p, ["admin", "data", "write"]})
    assert Acx.EnforcerServer.allow?(ename, ["admin", "data", "write"])
  end
  
  test "user permissions", %{enforcer_name: ename} do
    # Completely isolated from the "admin permissions" test
    Acx.EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
    assert Acx.EnforcerServer.allow?(ename, ["user", "data", "read"])
  end
end
```

### Manual Setup with TestHelper

If you need more control over the setup process:

```elixir
defmodule MyApp.PolicyTest do
  use ExUnit.Case, async: true
  import Acx.TestHelper
  
  setup do
    # Generate a unique name for this test's enforcer
    ename = unique_enforcer_name()
    
    # Start the enforcer with the unique name
    {:ok, _pid} = Acx.EnforcerSupervisor.start_enforcer(ename, "config.conf")
    
    # Load initial policies
    Acx.EnforcerServer.load_policies(ename, "policies.csv")
    
    # Register cleanup to run after the test
    on_exit(fn -> cleanup_enforcer(ename) end)
    
    {:ok, enforcer_name: ename}
  end
  
  test "some test", %{enforcer_name: ename} do
    # Use ename in your test
    Acx.EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
    assert Acx.EnforcerServer.allow?(ename, ["alice", "data", "read"])
  end
end
```

### Using Custom Name Prefixes

For better test output and debugging, you can use custom prefixes:

```elixir
setup do
  # Name will be like "acl_test_12345"
  setup_enforcer("acl_test", "path/to/config.conf")
end
```

Or manually:

```elixir
setup do
  ename = unique_enforcer_name("my_feature_test")
  # ename will be something like "my_feature_test_12345"
  ...
end
```

## Solution 2: Disable Async Tests

If you have existing tests that are difficult to refactor, you can disable async testing:

```elixir
defmodule MyApp.PolicyTest do
  use ExUnit.Case, async: false  # ✅ Tests run sequentially
  
  @enforcer_name "my_enforcer"
  
  # Rest of your existing test code...
end
```

**Trade-offs:**
- ✅ No code changes needed
- ✅ Tests still share state but run sequentially
- ❌ Tests run slower
- ❌ Doesn't scale well with many tests

## Solution 3: Use Enforcer Directly (No Server)

For pure unit tests that don't need the server functionality, use the `Acx.Enforcer` module directly:

```elixir
defmodule MyApp.EnforcerLogicTest do
  use ExUnit.Case, async: true  # ✅ Safe, no shared state
  
  alias Acx.Enforcer
  
  setup do
    {:ok, enforcer} = Enforcer.init("config.conf")
    enforcer = Enforcer.load_policies!(enforcer, "policies.csv")
    {:ok, enforcer: enforcer}
  end
  
  test "policy evaluation", %{enforcer: e} do
    # Each test gets its own enforcer struct
    {:ok, e} = Enforcer.add_policy(e, {:p, ["alice", "data", "read"]})
    assert Enforcer.allow?(e, ["alice", "data", "read"])
  end
end
```

**Benefits:**
- ✅ No server overhead
- ✅ Fully isolated, immutable state
- ✅ Perfect for testing policy logic
- ❌ Can't test server-specific features
- ❌ No persistence layer interaction

## Best Practices

1. **Always use unique enforcer names** when testing with `EnforcerServer`
2. **Clean up after tests** using `on_exit` callbacks
3. **Use `Acx.TestHelper.setup_enforcer/1`** for simple cases
4. **Consider `Enforcer` directly** for pure unit tests
5. **Document your test setup** so other developers understand the pattern

## Migration Guide

If you have existing tests with shared state, here's how to migrate:

### Before (Problematic)

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true
  
  @enforcer "my_app_enforcer"
  
  setup do
    Acx.EnforcerSupervisor.start_enforcer(@enforcer, "acl.conf")
    on_exit(fn ->
      # This cleanup affects other running tests!
      Acx.EnforcerServer.remove_policy(@enforcer, {:p, ["admin", "data", "write"]})
    end)
    :ok
  end
end
```

### After (Fixed)

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true
  import Acx.TestHelper
  
  setup do
    setup_enforcer("acl.conf")
  end
  
  test "admin can write", %{enforcer_name: ename} do
    Acx.EnforcerServer.add_policy(ename, {:p, ["admin", "data", "write"]})
    assert Acx.EnforcerServer.allow?(ename, ["admin", "data", "write"])
  end
end
```

## Additional Resources

- See `test/test_helper_test.exs` for complete examples
- Review the `Acx.TestHelper` module documentation for all available functions
- Check the main README for general Casbin-Ex usage

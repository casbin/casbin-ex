# Async Testing Guide

This guide explains how to write async tests with Acx enforcers without race conditions.

## The Problem

By default, `EnforcerServer` uses a global ETS table to cache enforcers by name. This causes tests with `async: true` to share state and interfere with each other:

```elixir
# ❌ FAILS with async: true
defmodule MyTest do
  use ExUnit.Case, async: true  # Tests interfere!
  
  setup do
    EnforcerServer.start_link("my_enforcer", config_file)
    :ok
  end
  
  test "test 1" do
    EnforcerServer.add_policy("my_enforcer", {:p, ["user1", "data", "read"]})
    assert EnforcerServer.allow?("my_enforcer", ["user1", "data", "read"])
    # RACE CONDITION: Another test might clean up policies mid-test!
  end
  
  test "test 2" do
    # Both tests share the same "my_enforcer" instance
    # Policies from test 1 might still be present
  end
end
```

**Symptoms:**
- `list_policies()` returns `[]` even after adding policies
- `add_policy` returns `{:error, :already_existed}` but policies aren't visible
- Tests pass individually but fail when run together

## The Solution

Use **isolated enforcers** that don't share state between tests.

### Option 1: Test Helper (Recommended)

The easiest approach is to use `Acx.EnforcerTestHelper`:

```elixir
# ✅ WORKS with async: true
defmodule MyTest do
  use ExUnit.Case, async: true
  import Acx.EnforcerTestHelper
  
  setup do
    # Each test gets a unique, isolated enforcer
    {:ok, ename, _pid} = start_test_enforcer("my_test", config_file)
    {:ok, ename: ename}
  end
  
  test "test 1", %{ename: ename} do
    # This test has its own enforcer instance
    EnforcerServer.add_policy(ename, {:p, ["user1", "data", "read"]})
    assert EnforcerServer.allow?(ename, ["user1", "data", "read"])
  end
  
  test "test 2", %{ename: ename} do
    # This test also has its own enforcer instance (different from test 1)
    EnforcerServer.add_policy(ename, {:p, ["user2", "data", "write"]})
    assert EnforcerServer.allow?(ename, ["user2", "data", "write"])
    
    # No interference from test 1
    refute EnforcerServer.allow?(ename, ["user1", "data", "read"])
  end
end
```

The test helper:
- Generates a unique enforcer name for each test
- Starts an isolated enforcer (bypasses ETS cache)
- Automatically cleans up the enforcer when the test completes

### Option 2: Manual Management

For more control, manually manage isolated enforcers:

```elixir
defmodule MyTest do
  use ExUnit.Case, async: true
  
  test "manual control" do
    # Generate unique name
    ename = Acx.EnforcerServer.unique_name("test")
    
    # Start isolated enforcer
    {:ok, _pid} = Acx.EnforcerServer.start_link_isolated(ename, config_file)
    
    # Use the enforcer
    EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
    assert EnforcerServer.allow?(ename, ["user", "data", "read"])
    
    # Clean up
    on_exit(fn ->
      Acx.EnforcerTestHelper.stop_enforcer(ename)
    end)
  end
end
```

### Option 3: Supervised Isolated Enforcers

If you need supervised enforcers in tests:

```elixir
setup do
  {:ok, ename, _pid} = start_test_enforcer("my_test", config_file, supervised: true)
  {:ok, ename: ename}
end
```

This uses `EnforcerSupervisor.start_enforcer_isolated/2` instead of `EnforcerServer.start_link_isolated/2`.

## API Reference

### EnforcerServer

- **`start_link/2`** - Standard enforcer (uses ETS cache, shared state)
- **`start_link_isolated/2`** - Isolated enforcer (no ETS cache, unique state)
- **`unique_name/1`** - Generate a unique enforcer name

### EnforcerSupervisor

- **`start_enforcer/2`** - Standard supervised enforcer (uses ETS cache)
- **`start_enforcer_isolated/2`** - Isolated supervised enforcer (no ETS cache)

### EnforcerTestHelper

- **`start_test_enforcer/3`** - Start isolated enforcer with automatic cleanup
- **`unique_enforcer_name/1`** - Generate a unique enforcer name
- **`stop_enforcer/1`** - Gracefully stop an enforcer

## Examples

See `examples/async_test_example.exs` for complete working examples.

## Migration Guide

### Before (async: false required)

```elixir
defmodule MyTest do
  use ExUnit.Case  # async: false (default)
  
  @enforcer_name "my_enforcer"
  
  setup do
    EnforcerServer.start_link(@enforcer_name, config_file)
    on_exit(fn -> cleanup_enforcer(@enforcer_name) end)
    :ok
  end
  
  test "my test" do
    EnforcerServer.add_policy(@enforcer_name, policy)
    # ...
  end
end
```

### After (async: true supported)

```elixir
defmodule MyTest do
  use ExUnit.Case, async: true  # Now safe!
  import Acx.EnforcerTestHelper
  
  setup do
    {:ok, ename, _pid} = start_test_enforcer("my_test", config_file)
    {:ok, ename: ename}
  end
  
  test "my test", %{ename: ename} do
    EnforcerServer.add_policy(ename, policy)
    # ...
  end
end
```

## Benefits

1. **Faster Tests**: Async tests run in parallel
2. **No Race Conditions**: Each test has isolated state
3. **Cleaner Tests**: Automatic cleanup with `start_test_enforcer/3`
4. **Better CI**: Parallel test execution in CI pipelines

## When to Use Each Approach

| Scenario | Recommendation |
|----------|---------------|
| Async tests | Use `start_link_isolated/2` or test helper |
| Sequential tests | Use `start_link/2` (original behavior) |
| Production code | Use `start_link/2` (original behavior) |
| Integration tests | Use `start_link/2` with shared state |
| Unit tests | Use `start_link_isolated/2` for isolation |

## Performance Considerations

Isolated enforcers have minimal overhead:
- Each enforcer is a separate GenServer process
- No ETS lookup/insert operations
- Enforcer creation time is the same
- Memory usage scales with number of concurrent tests

For large test suites, async tests with isolated enforcers will be significantly faster than sequential tests with shared enforcers.

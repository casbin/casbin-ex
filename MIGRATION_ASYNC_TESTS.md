# Migration Guide: Enabling Async Tests

This guide helps you migrate existing test suites to use async tests with isolated enforcers.

## Quick Summary

**Before:** Tests used `async: false` (or default) because shared enforcer state caused race conditions.

**After:** Tests can use `async: true` with isolated enforcers for faster, parallel test execution.

## Step-by-Step Migration

### Step 1: Add the Test Helper Import

Add the test helper import to your test module:

```diff
  defmodule MyApp.CasbinTest do
-   use ExUnit.Case
+   use ExUnit.Case, async: true
+   import Acx.EnforcerTestHelper
    
    # ...
  end
```

### Step 2: Update Setup

Replace static enforcer names with dynamic, isolated enforcers:

**Before:**
```elixir
setup do
  @enforcer_name = "my_enforcer"
  {:ok, _pid} = Acx.EnforcerServer.start_link(@enforcer_name, @config_file)
  
  on_exit(fn ->
    # Manual cleanup
    GenServer.stop(via_tuple(@enforcer_name))
  end)
  
  :ok
end
```

**After:**
```elixir
setup do
  # Creates isolated enforcer with automatic cleanup
  {:ok, ename, _pid} = start_test_enforcer("my_enforcer", @config_file)
  {:ok, ename: ename}
end
```

### Step 3: Update Tests to Use Dynamic Name

Update all test functions to use the dynamic enforcer name from context:

**Before:**
```elixir
test "admin has full access" do
  Acx.EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "data", "write"]})
  assert Acx.EnforcerServer.allow?(@enforcer_name, ["admin", "data", "write"])
end
```

**After:**
```elixir
test "admin has full access", %{ename: ename} do
  Acx.EnforcerServer.add_policy(ename, {:p, ["admin", "data", "write"]})
  assert Acx.EnforcerServer.allow?(ename, ["admin", "data", "write"])
end
```

### Step 4: Enable Async

If you haven't already, enable async in your test module:

```diff
- use ExUnit.Case
+ use ExUnit.Case, async: true
```

## Complete Example

### Before Migration

```elixir
defmodule MyApp.CasbinTest do
  use ExUnit.Case
  
  @enforcer_name "test_enforcer"
  @config_file "test/config/acl.conf"
  
  setup do
    {:ok, _pid} = Acx.EnforcerServer.start_link(@enforcer_name, @config_file)
    
    on_exit(fn ->
      try do
        GenServer.stop({:via, Registry, {Acx.EnforcerRegistry, @enforcer_name}})
      catch
        :exit, _ -> :ok
      end
    end)
    
    :ok
  end
  
  test "user can read own data" do
    Acx.EnforcerServer.add_policy(@enforcer_name, {:p, ["user1", "data1", "read"]})
    assert Acx.EnforcerServer.allow?(@enforcer_name, ["user1", "data1", "read"])
  end
  
  test "user cannot read other data" do
    Acx.EnforcerServer.add_policy(@enforcer_name, {:p, ["user1", "data1", "read"]})
    refute Acx.EnforcerServer.allow?(@enforcer_name, ["user1", "data2", "read"])
  end
end
```

### After Migration

```elixir
defmodule MyApp.CasbinTest do
  use ExUnit.Case, async: true  # ← Now async!
  import Acx.EnforcerTestHelper   # ← Added import
  
  @config_file "test/config/acl.conf"
  
  setup do
    # ← Simplified setup with automatic cleanup
    {:ok, ename, _pid} = start_test_enforcer("test_enforcer", @config_file)
    {:ok, ename: ename}
  end
  
  test "user can read own data", %{ename: ename} do  # ← Added context param
    Acx.EnforcerServer.add_policy(ename, {:p, ["user1", "data1", "read"]})
    assert Acx.EnforcerServer.allow?(ename, ["user1", "data1", "read"])
  end
  
  test "user cannot read other data", %{ename: ename} do  # ← Added context param
    Acx.EnforcerServer.add_policy(ename, {:p, ["user1", "data1", "read"]})
    refute Acx.EnforcerServer.allow?(ename, ["user1", "data2", "read"])
  end
end
```

## Common Patterns

### Pattern 1: Module Attribute for Config

If you use module attributes for configuration, no changes needed:

```elixir
@config_file "path/to/config.conf"

setup do
  {:ok, ename, _pid} = start_test_enforcer("enforcer", @config_file)
  {:ok, ename: ename}
end
```

### Pattern 2: Custom Setup with Policies

If you load initial policies in setup:

**Before:**
```elixir
setup do
  {:ok, _pid} = Acx.EnforcerServer.start_link(@enforcer_name, @config_file)
  Acx.EnforcerServer.load_policies(@enforcer_name, @policy_file)
  :ok
end
```

**After:**
```elixir
setup do
  {:ok, ename, _pid} = start_test_enforcer("enforcer", @config_file)
  Acx.EnforcerServer.load_policies(ename, @policy_file)
  {:ok, ename: ename}
end
```

### Pattern 3: Describe Blocks

Works seamlessly with describe blocks:

```elixir
describe "admin permissions" do
  setup %{ename: ename} do
    # Add admin-specific setup
    Acx.EnforcerServer.add_policy(ename, {:p, ["admin", "data", "manage"]})
    :ok
  end
  
  test "admin can create", %{ename: ename} do
    assert Acx.EnforcerServer.allow?(ename, ["admin", "data", "create"])
  end
  
  test "admin can delete", %{ename: ename} do
    assert Acx.EnforcerServer.allow?(ename, ["admin", "data", "delete"])
  end
end
```

### Pattern 4: Multiple Enforcers

If you need multiple enforcers in one test:

```elixir
test "multiple enforcers" do
  {:ok, ename1, _} = start_test_enforcer("enforcer1", @config_file)
  {:ok, ename2, _} = start_test_enforcer("enforcer2", @config_file)
  
  # Each has independent state
  Acx.EnforcerServer.add_policy(ename1, {:p, ["user1", "data", "read"]})
  Acx.EnforcerServer.add_policy(ename2, {:p, ["user2", "data", "write"]})
  
  assert Acx.EnforcerServer.allow?(ename1, ["user1", "data", "read"])
  refute Acx.EnforcerServer.allow?(ename1, ["user2", "data", "write"])
end
```

## Gradual Migration

You don't have to migrate all tests at once. You can:

1. **Keep existing tests as-is** (they still work)
2. **Migrate new tests** to use async pattern
3. **Gradually migrate old tests** as you touch them

Both patterns can coexist:

```elixir
# Old test (still works)
defmodule OldTest do
  use ExUnit.Case  # async: false
  # Uses static enforcer names...
end

# New test (migrated)
defmodule NewTest do
  use ExUnit.Case, async: true
  import Acx.EnforcerTestHelper
  # Uses isolated enforcers...
end
```

## Troubleshooting

### Issue: Tests still interfere with each other

**Cause:** Not using `start_test_enforcer` or `start_link_isolated`

**Solution:** Make sure you're using isolated enforcers:
```elixir
# ❌ Wrong - uses shared state
Acx.EnforcerServer.start_link("name", config)

# ✅ Right - uses isolated state
start_test_enforcer("name", config)
# or
Acx.EnforcerServer.start_link_isolated(unique_name, config)
```

### Issue: Enforcer not cleaned up after test

**Cause:** Not using `start_test_enforcer` which provides automatic cleanup

**Solution:** Use `start_test_enforcer/3` or manually register cleanup:
```elixir
on_exit(fn ->
  Acx.EnforcerTestHelper.stop_enforcer(ename)
end)
```

### Issue: Module attribute not working

**Cause:** Trying to use module attribute for enforcer name

**Solution:** Use dynamic names from setup context:
```elixir
# ❌ Wrong - module attribute is static
@enforcer_name "static_name"

# ✅ Right - dynamic from setup
setup do
  {:ok, ename, _} = start_test_enforcer("base_name", config)
  {:ok, ename: ename}
end
```

## Performance Benefits

After migration, you should see:

- **Faster test suite**: Tests run in parallel
- **Better CI times**: Parallel execution in CI
- **No flaky tests**: No race conditions
- **Better isolation**: Tests don't affect each other

Example improvement:
```
Before: 100 tests in 30 seconds (sequential)
After:  100 tests in 8 seconds (parallel with async: true)
```

## Need Help?

- See `ASYNC_TESTING.md` for detailed guide
- See `examples/async_test_example.exs` for examples
- Check `test/enforcer_async_test.exs` for reference implementation

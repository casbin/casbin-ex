# Async Testing with Casbin

This guide explains how to write tests with `async: true` when using Casbin-Ex, enabling faster parallel test execution.

## The Problem

By default, if multiple tests share the same enforcer name, they will share the same global state in the ETS table. This causes race conditions when running tests with `async: true`:

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true  # ❌ Tests will interfere with each other
  
  @enforcer_name "my_enforcer"  # Shared global state!
  
  test "test 1" do
    EnforcerServer.add_policy(@enforcer_name, {:p, ["alice", "data", "read"]})
    # Another test's cleanup might delete this policy before we check it!
  end
  
  test "test 2" do
    EnforcerServer.add_policy(@enforcer_name, {:p, ["bob", "data", "write"]})
    # Policies from test 1 might still be present!
  end
end
```

**Symptoms:**
- `list_policies()` returns `[]` even after adding policies
- `add_policy` returns `{:error, :already_existed}` but policies aren't visible
- Tests pass individually but fail when run together
- Intermittent test failures

## Solution 1: Unique Enforcer Names Per Test

The recommended solution is to use `Casbin.TestHelper` to create isolated enforcer instances for each test:

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true  # ✅ Safe with isolated enforcers
  import Casbin.TestHelper
  
  setup do
    # Create a unique enforcer for this test
    enforcer_name = unique_enforcer_name()
    cfile = Path.expand("../data/model.conf", __DIR__)
    
    {:ok, _pid} = start_test_enforcer(enforcer_name, cfile)
    
    # Clean up after the test
    on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)
    
    {:ok, enforcer_name: enforcer_name}
  end
  
  test "alice can read data", %{enforcer_name: name} do
    :ok = EnforcerServer.add_policy(name, {:p, ["alice", "data", "read"]})
    assert EnforcerServer.allow?(name, ["alice", "data", "read"])
  end
  
  test "bob can write data", %{enforcer_name: name} do
    :ok = EnforcerServer.add_policy(name, {:p, ["bob", "data", "write"]})
    assert EnforcerServer.allow?(name, ["bob", "data", "write"])
  end
end
```

### With Custom Prefix

You can add a prefix to make enforcer names more readable in logs:

```elixir
setup do
  enforcer_name = unique_enforcer_name("acl_test")
  # Generates: "test_enforcer_acl_test_12345_67890_123456"
  
  cfile = Path.expand("../data/model.conf", __DIR__)
  {:ok, _pid} = start_test_enforcer(enforcer_name, cfile)
  
  on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)
  
  {:ok, enforcer_name: enforcer_name}
end
```

## Solution 2: Using the Enforcer Struct Directly

For tests that don't need the `EnforcerServer` process, use the `Enforcer` struct directly:

```elixir
defmodule MyApp.EnforcerTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer
  
  setup do
    cfile = Path.expand("../data/model.conf", __DIR__)
    {:ok, e} = Enforcer.init(cfile)
    {:ok, enforcer: e}
  end
  
  test "alice permissions", %{enforcer: e} do
    {:ok, e} = Enforcer.add_policy(e, {:p, ["alice", "data", "read"]})
    assert Enforcer.allow?(e, ["alice", "data", "read"])
  end
  
  test "bob permissions", %{enforcer: e} do
    {:ok, e} = Enforcer.add_policy(e, {:p, ["bob", "data", "write"]})
    assert Enforcer.allow?(e, ["bob", "data", "write"])
  end
end
```

This approach:
- ✅ No shared state - each test gets its own enforcer struct
- ✅ Fully isolated - perfect for `async: true`
- ✅ No cleanup needed
- ❌ Can't use `EnforcerServer` API (if you need that, use Solution 1)

## Solution 3: Disable Async (Not Recommended)

As a last resort, you can disable async testing:

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case  # async: false is the default
  
  @enforcer_name "my_enforcer"
  
  # Tests run serially, no race conditions
end
```

**Drawbacks:**
- ❌ Slower test suite
- ❌ Doesn't scale well
- ❌ Only use if you absolutely must share an enforcer between tests

## Using with Ecto.Adapters.SQL.Sandbox

When using Casbin with an `EctoAdapter`, you need special handling for the sandbox. See the [sandbox_testing.md](sandbox_testing.md) guide for details.

Quick example:

```elixir
defmodule MyApp.AclWithDbTest do
  use MyApp.DataCase, async: false  # Note: async: false with Ecto transactions
  import Casbin.TestHelper
  
  alias MyApp.Repo
  
  setup do
    # Sandbox setup
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    
    # Enforcer setup
    enforcer_name = unique_enforcer_name()
    cfile = Path.expand("../data/model.conf", __DIR__)
    {:ok, pid} = start_test_enforcer(enforcer_name, cfile)
    
    # Allow enforcer to access DB
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
    
    # Set Ecto adapter
    adapter = Casbin.Persist.EctoAdapter.new(Repo)
    :ok = EnforcerServer.set_persist_adapter(enforcer_name, adapter)
    
    on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)
    
    {:ok, enforcer_name: enforcer_name}
  end
  
  test "persist policies to database", %{enforcer_name: name} do
    :ok = EnforcerServer.add_policy(name, {:p, ["alice", "data", "read"]})
    :ok = EnforcerServer.save_policies(name)
    
    # Verify in database...
  end
end
```

## Helper Functions Reference

### `unique_enforcer_name(prefix \\ "")`

Generates a unique name for an enforcer instance.

**Parameters:**
- `prefix` (optional) - A string prefix for the name

**Returns:** A unique string like `"test_enforcer_12345_67890_123456"`

### `start_test_enforcer(enforcer_name, config_file)`

Starts an enforcer process under the test supervisor.

**Parameters:**
- `enforcer_name` - Unique name (from `unique_enforcer_name/0`)
- `config_file` - Path to Casbin model config file

**Returns:** `{:ok, pid}` or `{:error, reason}`

### `cleanup_test_enforcer(enforcer_name)`

Stops the enforcer process and removes it from the ETS table.

**Parameters:**
- `enforcer_name` - Name of the enforcer to clean up

**Returns:** `:ok`

**Usage:** Always call in `on_exit/1`:
```elixir
on_exit(fn -> cleanup_test_enforcer(enforcer_name) end)
```

### `reset_test_enforcer(enforcer_name, config_file)`

Resets an enforcer to its initial state without stopping it.

**Parameters:**
- `enforcer_name` - Name of the enforcer
- `config_file` - Config file to reload

**Returns:** `:ok` or `{:error, reason}`

**Usage:** Useful for clearing policies between test cases:
```elixir
describe "with clean state" do
  setup %{enforcer_name: name, cfile: cfile} do
    reset_test_enforcer(name, cfile)
    :ok
  end
  
  test "test 1", %{enforcer_name: name} do
    # Clean state guaranteed
  end
end
```

## Best Practices

1. **Always use unique names** - Use `unique_enforcer_name()` to avoid conflicts
2. **Always cleanup** - Use `on_exit/1` to ensure cleanup even if tests fail
3. **Prefer Enforcer struct** - If you don't need `EnforcerServer`, use `Enforcer` directly
4. **One enforcer per test** - Don't try to share enforcers between tests
5. **Use prefixes** - Add readable prefixes to enforcer names for easier debugging

## Migration Guide

### Before (async: false)

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case  # async: false
  
  @enforcer_name "my_enforcer"
  
  test "alice test" do
    EnforcerServer.add_policy(@enforcer_name, {:p, ["alice", "data", "read"]})
    assert EnforcerServer.allow?(@enforcer_name, ["alice", "data", "read"])
  end
end
```

### After (async: true)

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true
  import Casbin.TestHelper
  
  setup do
    name = unique_enforcer_name()
    cfile = "path/to/config.conf"
    {:ok, _} = start_test_enforcer(name, cfile)
    on_exit(fn -> cleanup_test_enforcer(name) end)
    {:ok, enforcer_name: name}
  end
  
  test "alice test", %{enforcer_name: name} do
    EnforcerServer.add_policy(name, {:p, ["alice", "data", "read"]})
    assert EnforcerServer.allow?(name, ["alice", "data", "read"])
  end
end
```

## See Also

- [Sandbox Testing Guide](sandbox_testing.md) - Using Casbin with Ecto.Adapters.SQL.Sandbox
- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html) - ExUnit testing framework
- [Casbin Model Configuration](https://casbin.org/docs/syntax-for-models) - Writing model files

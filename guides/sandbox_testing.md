# Testing with Casbin-Ex

This guide covers two important testing scenarios:

1. **Async Testing with Isolated Enforcers** - Running tests concurrently without race conditions
2. **Testing with Ecto.Adapters.SQL.Sandbox and Transactions** - Using Casbin with database transactions

## Async Testing with Isolated Enforcers

### The Problem

When using `EnforcerServer` with a shared enforcer name across tests, all tests use the same global state through the `:enforcers_table` ETS table. This causes race conditions when running tests with `async: true`:

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true  # ❌ Tests interfere with each other
  
  @enforcer_name "my_enforcer"  # ❌ Shared across all tests
  
  test "admin has permissions" do
    EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "data", "read"]})
    # Another test's cleanup might delete this policy mid-test!
    assert EnforcerServer.allow?(@enforcer_name, ["admin", "data", "read"])
  end
end
```

**Symptoms:**
- `list_policies()` returns `[]` even after adding policies
- `add_policy` returns `{:error, :already_existed}` but policies aren't in the returned list
- Tests pass individually but fail when run together
- One test's cleanup deletes policies while another test is running

### Solution: Use Isolated Enforcers

Casbin-Ex provides `Casbin.AsyncTestHelper` to create isolated enforcer instances for each test:

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true  # ✅ Safe to use async now
  
  alias Casbin.AsyncTestHelper
  alias Casbin.EnforcerServer

  @model_path "path/to/model.conf"

  setup do
    # Each test gets a unique enforcer name
    AsyncTestHelper.setup_isolated_enforcer(@model_path)
  end

  test "admin has permissions", %{enforcer_name: enforcer_name} do
    # Use the unique enforcer_name - no race conditions!
    :ok = EnforcerServer.add_policy(
      enforcer_name,
      {:p, ["admin", "data", "read"]}
    )
    
    assert EnforcerServer.allow?(enforcer_name, ["admin", "data", "read"])
    
    # Automatic cleanup happens via on_exit callback
  end

  test "user has limited permissions", %{enforcer_name: enforcer_name} do
    # This test has its own isolated enforcer
    :ok = EnforcerServer.add_policy(
      enforcer_name,
      {:p, ["user", "data", "read"]}
    )
    
    assert EnforcerServer.allow?(enforcer_name, ["user", "data", "read"])
    refute EnforcerServer.allow?(enforcer_name, ["user", "data", "write"])
  end
end
```

### Manual Setup (Alternative)

If you need more control, you can manually manage the enforcer lifecycle:

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true
  
  alias Casbin.AsyncTestHelper
  alias Casbin.EnforcerServer

  setup do
    # Generate unique enforcer name
    enforcer_name = AsyncTestHelper.unique_enforcer_name()
    
    # Start isolated enforcer
    {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(
      enforcer_name,
      "path/to/model.conf"
    )
    
    # Optional: Load initial policies
    EnforcerServer.load_policies(enforcer_name, "path/to/policies.csv")
    
    # Cleanup on test exit
    on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)
    
    {:ok, enforcer: enforcer_name}
  end

  test "my test", %{enforcer: enforcer_name} do
    # Use enforcer_name in your test
  end
end
```

### How It Works

`AsyncTestHelper` ensures test isolation by:

1. **Unique Names**: Generates unique enforcer names using monotonic integers
2. **Isolated State**: Each enforcer gets its own entry in the ETS table and Registry
3. **Automatic Cleanup**: Stops the enforcer process and removes ETS/Registry entries after tests

This allows tests to run concurrently without interfering with each other.

### When to Use Async Testing

Use isolated enforcers with `async: true` when:
- Tests don't require database transactions
- You want faster test execution through parallelization  
- Tests are independent and don't share state
- You're testing pure Casbin logic without external dependencies

Use `async: false` when:
- Tests require database transactions (see next section)
- Tests need to share a specific enforcer configuration
- You're testing integration with external systems

---

## Testing with Ecto.Adapters.SQL.Sandbox and Transactions

This section explains how to use Casbin-Ex with `Ecto.Adapters.SQL.Sandbox` when you need to wrap Casbin operations in database transactions.

## The Problem

When using `Ecto.Adapters.SQL.Sandbox` in checkout mode (the default), database connections are restricted to the process that checked them out. The Casbin `EnforcerServer` runs in a separate process, which causes issues when:

1. Your test wraps Casbin operations in a `Repo.transaction`
2. The transaction locks the connection to the test process
3. The `EnforcerServer` process cannot access the locked connection, even with `Sandbox.allow/3`

This results in the error:
```
** (DBConnection.ConnectionError) could not checkout the connection owned by #PID<...>
```

## Solution: Use Shared Mode

The recommended solution is to use Ecto's **shared mode** for tests that need to call Casbin within transactions:

```elixir
defmodule MyApp.RolesTest do
  use MyApp.DataCase
  use MyApp.CasbinCase

  setup do
    # Check out a connection
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
    
    # Enable shared mode - this allows the EnforcerServer to use the connection
    Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
    
    # Allow the EnforcerServer process to access the connection
    case Registry.lookup(Casbin.EnforcerRegistry, "my_enforcer") do
      [{enforcer_pid, _}] ->
        Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, self(), enforcer_pid)
      [] ->
        :ok
    end
    
    :ok
  end

  test "create role with permissions in transaction" do
    permissions = [
      %{resource: "orgs", action: "read"},
      %{resource: "users", action: "read"}
    ]

    # This now works because of shared mode
    assert {:ok, :created} = 
      MyApp.Repo.transaction(fn ->
        Enum.each(permissions, fn %{resource: resource, action: action} ->
          case Casbin.EnforcerServer.add_policy("my_enforcer", {:p, ["analyst", resource, action]}) do
            :ok -> :ok
            {:error, reason} -> MyApp.Repo.rollback(reason)
          end
        end)
        
        {:ok, :created}
      end)
  end
end
```

## Important Notes

### About Shared Mode

- **Shared mode** allows multiple processes to access the same database connection
- All tests in a module using shared mode will share the connection
- This may reduce test isolation compared to the default checkout mode
- It's still safe because each test gets a clean transaction that's rolled back

### When to Use Shared Mode

Use shared mode when you need to:
- Wrap Casbin operations in application-level transactions
- Test rollback behavior with Casbin
- Test atomic operations that involve both Casbin and other database changes

### Alternative Approaches

If you don't need transactions in your tests, you can:

1. **Avoid wrapping in transactions**: Call Casbin operations directly without `Repo.transaction`
2. **Test transactions separately**: Test transaction logic separately from Casbin operations
3. **Use async: false**: Use `async: false` to run tests serially with shared connections

## Example Test Module

Here's a complete example of a test module using shared mode:

```elixir
defmodule MyApp.Authorization.RolesTest do
  use MyApp.DataCase, async: false  # async: false for shared mode
  
  alias MyApp.Repo
  alias MyApp.Authorization.Roles
  
  setup do
    # Set up sandbox in shared mode
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    
    # Allow EnforcerServer to access the connection
    case Registry.lookup(Casbin.EnforcerRegistry, "my_enforcer") do
      [{pid, _}] -> Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      [] -> :ok
    end
    
    :ok
  end

  test "creates role with permissions atomically" do
    permissions = [
      %{resource: "users", action: "read"},
      %{resource: "users", action: "write"}
    ]

    # This transaction includes Casbin operations
    result = Repo.transaction(fn ->
      # Create database record
      {:ok, role} = Roles.create_role_record("admin")
      
      # Add Casbin policies
      Enum.each(permissions, fn perm ->
        case Casbin.EnforcerServer.add_policy(
          "my_enforcer",
          {:p, ["admin", perm.resource, perm.action]}
        ) do
          :ok -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      
      {:ok, role}
    end)

    assert {:ok, _role} = result
  end

  test "rolls back Casbin operations on error" do
    result = Repo.transaction(fn ->
      # Add a policy
      :ok = Casbin.EnforcerServer.add_policy(
        "my_enforcer",
        {:p, ["temp_role", "resource", "action"]}
      )
      
      # Simulate an error
      Repo.rollback(:simulated_error)
    end)

    assert {:error, :simulated_error} = result
    
    # Verify the policy was not persisted
    policies = Casbin.EnforcerServer.list_policies("my_enforcer", %{sub: "temp_role"})
    assert policies == []
  end
end
```

## Further Reading

- [Casbin.AsyncTestHelper Documentation](../test/support/async_test_helper.ex) - For async testing with isolated enforcers
- [Ecto.Adapters.SQL.Sandbox Documentation](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Ecto.Adapters.SQL.Sandbox Shared Mode](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#module-shared-mode)
- [Testing with Ecto](https://hexdocs.pm/ecto/testing-with-ecto.html)

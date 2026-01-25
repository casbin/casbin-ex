# Fix Shared Global Enforcer State Breaking Async Tests

## Problem Statement

When using `EnforcerServer` with a named enforcer (e.g., "reach_enforcer"), all tests share the same global state through the `:enforcers_table` ETS table and `Casbin.EnforcerRegistry`. This causes race conditions when running tests with `async: true`:

### Symptoms
- `list_policies()` returns `[]` even after adding policies
- `add_policy` returns `{:error, :already_existed}` but policies aren't in memory
- Tests pass individually but fail when run together
- One test's cleanup deletes policies while another test is running

### Root Cause
```elixir
# All tests use the same enforcer instance
@enforcer_name "reach_enforcer"
EnforcerServer.add_policy(@enforcer_name, ...)
```
One test's `on_exit` cleanup deletes policies while another test is running concurrently.

## Solution

Added `Casbin.AsyncTestHelper` module that provides utilities for test isolation with unique enforcer instances per test.

## Implementation

### New Modules

1. **`test/support/async_test_helper.ex`** (190 lines)
   - `unique_enforcer_name/0` - Generates unique names using monotonic integers
   - `start_isolated_enforcer/2` - Starts an isolated enforcer for a test
   - `stop_enforcer/1` - Cleans up enforcer and removes ETS/Registry entries
   - `setup_isolated_enforcer/2` - Convenience function combining setup and cleanup

2. **`test/async_test_helper_test.exs`** (243 lines)
   - 13 comprehensive tests validating the helper functionality
   - Tests for unique name generation, isolation, concurrent operations
   - Demonstrates safe concurrent test execution

3. **`test/async_enforcer_server_test.exs`** (160 lines)
   - Practical examples demonstrating the solution
   - Shows how to use `EnforcerServer` with async tests
   - Validates that the race condition issue is resolved

### Updated Files

1. **`guides/sandbox_testing.md`** (+142 lines)
   - Added comprehensive section on async testing
   - Includes usage examples and best practices
   - Explains when to use async vs sync tests

2. **`.gitignore`** (+11 lines)
   - Added patterns to exclude temporary test files

## Usage

### Before (❌ Has Race Conditions)
```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true  # ❌ Race conditions!
  
  @enforcer_name "my_enforcer"  # ❌ Shared state
  
  test "admin has permissions" do
    EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "data", "read"]})
    # May fail if another test cleans up the enforcer
    assert EnforcerServer.allow?(@enforcer_name, ["admin", "data", "read"])
  end
end
```

### After (✅ No Race Conditions)
```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true  # ✅ Safe!
  
  alias Casbin.AsyncTestHelper

  setup do
    # Each test gets a unique enforcer instance
    AsyncTestHelper.setup_isolated_enforcer("path/to/model.conf")
  end

  test "admin has permissions", %{enforcer_name: enforcer_name} do
    :ok = EnforcerServer.add_policy(
      enforcer_name,
      {:p, ["admin", "data", "read"]}
    )
    # Always works - isolated from other tests
    assert EnforcerServer.allow?(enforcer_name, ["admin", "data", "read"])
  end
end
```

## Testing

All 13 new tests pass successfully, demonstrating:
- ✅ Unique name generation without collisions
- ✅ Proper enforcer isolation for concurrent tests
- ✅ Independent state maintenance across multiple enforcers
- ✅ Correct cleanup and idempotency
- ✅ Deterministic test behavior (no randomness)

## Benefits

1. **Enables async testing** - Tests can run concurrently without interference
2. **No breaking changes** - Purely additive, doesn't modify existing library code
3. **Well documented** - Comprehensive examples and guide updates
4. **Test isolation** - Each test gets a fresh enforcer instance
5. **Backward compatible** - Existing tests continue to work unchanged
6. **Production ready** - No security issues (verified by CodeQL)

## Code Quality

- ✅ All code review feedback addressed
- ✅ Comments accurately reflect implementation
- ✅ Code is deterministic (no random values in tests)
- ✅ Efficient implementations using Elixir idioms
- ✅ No security vulnerabilities detected
- ✅ Comprehensive documentation and examples

## Files Changed

```
 .gitignore                          |  11 ++++
 guides/sandbox_testing.md           | 142 +++++++++++++++++++++++++++++
 test/async_enforcer_server_test.exs | 160 +++++++++++++++++++++++++++++++
 test/async_test_helper_test.exs     | 243 ++++++++++++++++++++++++++++++++++++++++++
 test/support/async_test_helper.ex   | 190 +++++++++++++++++++++++++++++++++++
 5 files changed, 744 insertions(+), 2 deletions(-)
```

## Migration Guide

### For Projects Currently Affected

If you're experiencing the race condition issue:

1. Add the AsyncTestHelper to your test setup:
   ```elixir
   alias Casbin.AsyncTestHelper
   
   setup do
     AsyncTestHelper.setup_isolated_enforcer("path/to/model.conf")
   end
   ```

2. Update test functions to use the enforcer name from context:
   ```elixir
   test "my test", %{enforcer_name: enforcer_name} do
     EnforcerServer.add_policy(enforcer_name, ...)
   end
   ```

3. Enable async testing:
   ```elixir
   use ExUnit.Case, async: true
   ```

### For New Tests

Just use the `setup_isolated_enforcer/1` helper from the start.

## Notes

- The solution is purely additive - no changes to core library code
- Existing tests using `Enforcer` module directly (not `EnforcerServer`) are unaffected
- The helper works with any Casbin model configuration
- Cleanup is automatic via `on_exit` callbacks

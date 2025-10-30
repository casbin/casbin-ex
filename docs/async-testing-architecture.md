# Async Testing Architecture

This document explains the architecture of the async testing solution.

## Problem: Shared State Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Application.start/2                  │
│              (in lib/acx.ex)                            │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ├─→ Creates Registry (Acx.EnforcerRegistry)
                  └─→ Creates ETS Table (:enforcers_table)
                           │
                           │ Global Shared State
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
┌───────▼─────────┐               ┌───────▼─────────┐
│   Test 1        │               │   Test 2        │
│  async: true    │               │  async: true    │
└───────┬─────────┘               └───────┬─────────┘
        │                                 │
        │ start_link("enforcer")          │ start_link("enforcer")
        │                                 │
        └─────────┬──────────────┬────────┘
                  │              │
                  ▼              ▼
        ┌─────────────────────────────┐
        │  ETS Lookup                 │
        │  key: "enforcer"            │
        │  → Returns SAME instance    │
        └─────────────────────────────┘
                  │
                  ▼
        ┌─────────────────────────────┐
        │  Shared Enforcer Process    │
        │  ❌ RACE CONDITION          │
        │                             │
        │  Test 1: add_policy         │
        │  Test 2: remove_policy      │
        │  → Interfere with each other│
        └─────────────────────────────┘
```

## Solution: Isolated State Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Application.start/2                  │
│              (in lib/acx.ex)                            │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ├─→ Creates Registry (Acx.EnforcerRegistry)
                  └─→ Creates ETS Table (:enforcers_table)
                           │
                           │ Still available for production use
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
┌───────▼─────────┐               ┌───────▼─────────┐
│   Test 1        │               │   Test 2        │
│  async: true    │               │  async: true    │
└───────┬─────────┘               └───────┬─────────┘
        │                                 │
        │ start_link_isolated             │ start_link_isolated
        │ ("enforcer_123")                │ ("enforcer_456")
        │                                 │
        │                                 │
        ▼                                 ▼
┌─────────────────┐           ┌─────────────────┐
│ Skip ETS Lookup │           │ Skip ETS Lookup │
│ Create Fresh    │           │ Create Fresh    │
└────────┬────────┘           └────────┬────────┘
         │                             │
         ▼                             ▼
┌─────────────────┐           ┌─────────────────┐
│  Enforcer A     │           │  Enforcer B     │
│  ✅ ISOLATED   │           │  ✅ ISOLATED   │
│                 │           │                 │
│  Own policies   │           │  Own policies   │
│  Own state      │           │  Own state      │
│  No interference│           │  No interference│
└─────────────────┘           └─────────────────┘
```

## Code Flow Comparison

### Old Approach (Shared State)

```elixir
# Step 1: All tests use same name
test "test 1" do
  start_link("my_enforcer", config)  # ①
  # ...
end

test "test 2" do
  start_link("my_enforcer", config)  # ②
  # ...
end

# Step 2: Both calls hit create_new_or_lookup_enforcer/2
defp create_new_or_lookup_enforcer("my_enforcer", config) do
  case :ets.lookup(:enforcers_table, "my_enforcer") do
    [] -> 
      # First call: creates new enforcer
      {:ok, enforcer} = Enforcer.init(config)
      :ets.insert(:enforcers_table, {"my_enforcer", enforcer})
      {:ok, enforcer}
    
    [{_, enforcer}] -> 
      # Second call: returns SAME enforcer ← PROBLEM!
      {:ok, enforcer}
  end
end

# Result: Both tests share the same enforcer process
#         → Race conditions with async: true
```

### New Approach (Isolated State)

```elixir
# Step 1: Each test gets unique name
test "test 1" do
  ename = unique_name("test")          # → "test_123"
  start_link_isolated(ename, config)   # ①
  # ...
end

test "test 2" do
  ename = unique_name("test")          # → "test_456"
  start_link_isolated(ename, config)   # ②
  # ...
end

# Step 2: Both calls create fresh enforcers
def start_link_isolated(ename, config) do
  GenServer.start_link(__MODULE__, {ename, config, true}, name: via(ename))
end

def init({ename, config, isolated = true}) do
  # Skip ETS lookup, create fresh enforcer
  {:ok, enforcer} = create_isolated_enforcer(ename, config)
  {:ok, enforcer}
end

defp create_isolated_enforcer(_ename, config) do
  # Directly create new enforcer, no ETS caching
  Enforcer.init(config)
end

# Result: Each test has its own enforcer process
#         → No interference with async: true ✅
```

## Function Call Chain

### Shared State Path (Original)
```
start_link(name, config)
  ↓
init({name, config})  [backward compatible]
  ↓
init({name, config, false})
  ↓
create_new_or_lookup_enforcer(name, config)
  ↓
:ets.lookup(:enforcers_table, name)
  ↓
if exists → return cached enforcer
if not exists → create and cache new enforcer
```

### Isolated State Path (New)
```
start_link_isolated(name, config)
  ↓
init({name, config, true})
  ↓
create_isolated_enforcer(name, config)
  ↓
Enforcer.init(config)  [no ETS caching]
  ↓
return fresh enforcer
```

## Test Helper Flow

```
Test Setup:
  start_test_enforcer("base", config)
    ↓
  unique_name("base") → "base_123456"
    ↓
  start_link_isolated("base_123456", config)
    ↓
  register on_exit cleanup
    ↓
  return {:ok, "base_123456", pid}

Test Execution:
  EnforcerServer.add_policy("base_123456", policy)
  EnforcerServer.allow?("base_123456", request)
    ↓
  Uses isolated enforcer via Registry lookup
    ↓
  No interference with other tests

Test Teardown:
  on_exit callback executes
    ↓
  stop_enforcer("base_123456")
    ↓
  GenServer.stop(pid)
    ↓
  Enforcer cleaned up automatically
```

## Key Design Decisions

### 1. Backward Compatibility
- Keep `start_link/2` unchanged (uses ETS)
- Add new `start_link_isolated/2` (skips ETS)
- `init/2` dispatches to `init/3` with flag

### 2. Unique Names
- Use `erlang:unique_integer([:positive])`
- Guarantees uniqueness across the VM
- Human-readable format: "base_123456"

### 3. No ETS for Isolated Enforcers
- Isolated enforcers skip ETS entirely
- Still use Registry for process lookup
- Each test's enforcer is truly isolated

### 4. Automatic Cleanup
- `start_test_enforcer/3` registers `on_exit` callback
- Cleanup happens even if test fails
- Uses graceful `GenServer.stop` with timeout

### 5. Minimal Changes
- Core logic unchanged
- Only add isolation bypass
- No changes to Enforcer module itself

## Performance Characteristics

### Sequential Tests (Before)
```
Test 1: ████████ 2s
Test 2:         ████████ 2s
Test 3:                 ████████ 2s
Total: 6s
```

### Parallel Tests (After)
```
Test 1: ████████ 2s
Test 2: ████████ 2s
Test 3: ████████ 2s
Total: 2s (3x faster!)
```

## Security Considerations

✅ No security implications:
- No new external dependencies
- No network calls
- No privilege escalation
- Same security model as before

## Edge Cases Handled

1. **Test fails before cleanup**: `on_exit` still runs
2. **Enforcer already stopped**: `stop_enforcer/1` handles gracefully
3. **Invalid config file**: Error propagates correctly
4. **Name collision** (unlikely): Unique integers prevent this
5. **Supervisor crash**: Isolated enforcers restart independently

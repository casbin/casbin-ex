# Loading Policies from Database Adapter

This guide demonstrates how to use the new `load_policies/1` and `load_mapping_policies/1` functions to load policies from a database adapter (such as EctoAdapter) on application startup.

## The Problem

Previously, the EctoAdapter would automatically save policies to the database but provided no clean way to load them back into the enforcer's memory on application startup. This required developers to implement manual workarounds.

## The Solution

We've added overloaded versions of `EnforcerServer.load_policies/1` and `EnforcerServer.load_mapping_policies/1` that load policies from the configured persist adapter instead of requiring a file path.

## Usage Example

### Basic Setup with EctoAdapter

```elixir
alias Acx.{EnforcerSupervisor, EnforcerServer}
alias Acx.Persist.EctoAdapter

# 1. Start the enforcer with your model configuration
ename = "my_enforcer"
EnforcerSupervisor.start_enforcer(ename, "path/to/model.conf")

# 2. Configure the database adapter
adapter = EctoAdapter.new(MyApp.Repo)
EnforcerServer.set_persist_adapter(ename, adapter)

# 3. Load policies from the database
EnforcerServer.load_policies(ename)

# 4. Load mapping policies (for RBAC) from the database
EnforcerServer.load_mapping_policies(ename)

# Now your enforcer is ready to use!
EnforcerServer.allow?(ename, ["alice", "blog_post", "read"])
```

### Application Startup Integration

Here's how to integrate this into your Phoenix application's startup sequence:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Your repo
      MyApp.Repo,
      
      # Other children...
      
      # Start the enforcer supervisor
      {Acx.EnforcerSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    result = Supervisor.start_link(children, opts)
    
    # Initialize the enforcer after the supervisor starts
    initialize_enforcer()
    
    result
  end

  defp initialize_enforcer do
    alias Acx.{EnforcerSupervisor, EnforcerServer}
    alias Acx.Persist.EctoAdapter
    
    # Model configuration path
    model_path = Application.app_dir(:my_app, "priv/casbin/model.conf")
    
    # Start the enforcer
    ename = "my_app_enforcer"
    EnforcerSupervisor.start_enforcer(ename, model_path)
    
    # Set up database adapter
    adapter = EctoAdapter.new(MyApp.Repo)
    EnforcerServer.set_persist_adapter(ename, adapter)
    
    # Load policies from database
    EnforcerServer.load_policies(ename)
    EnforcerServer.load_mapping_policies(ename)
  end
end
```

### Adding Policies at Runtime

Once configured, new policies are automatically persisted:

```elixir
# Add a policy - automatically saved to database
EnforcerServer.add_policy("my_enforcer", {:p, ["admin", "data", "write"]})

# Add a role mapping - automatically saved to database
EnforcerServer.add_mapping_policy("my_enforcer", {:g, "alice", "admin"})

# On next application restart, these policies will be loaded automatically
```

### Working with Filtered Policies

You can also load only specific policies based on filters:

```elixir
# Load only policies for a specific domain
filter = %{v3: "org:tenant_123"}
EnforcerServer.load_filtered_policies("my_enforcer", filter)

# Load policies with multiple criteria
filter = %{ptype: "p", v3: ["org:tenant_1", "org:tenant_2"]}
EnforcerServer.load_filtered_policies("my_enforcer", filter)
```

## API Reference

### EnforcerServer.load_policies/1

Loads all policies from the configured persist adapter.

**Parameters:**
- `ename` - The name of the enforcer

**Returns:** `:ok`

**Example:**
```elixir
EnforcerServer.load_policies("my_enforcer")
```

### EnforcerServer.load_policies/2

Loads policies from a CSV file (original behavior, still supported).

**Parameters:**
- `ename` - The name of the enforcer
- `pfile` - Path to the policy CSV file

**Returns:** `:ok`

**Example:**
```elixir
EnforcerServer.load_policies("my_enforcer", "path/to/policies.csv")
```

### EnforcerServer.load_mapping_policies/1

Loads all mapping policies (role assignments) from the configured persist adapter.

**Parameters:**
- `ename` - The name of the enforcer

**Returns:** `:ok`

**Example:**
```elixir
EnforcerServer.load_mapping_policies("my_enforcer")
```

### EnforcerServer.load_mapping_policies/2

Loads mapping policies from a CSV file (original behavior, still supported).

**Parameters:**
- `ename` - The name of the enforcer
- `fname` - Path to the mapping policies CSV file

**Returns:** `:ok`

**Example:**
```elixir
EnforcerServer.load_mapping_policies("my_enforcer", "path/to/mappings.csv")
```

## Migration Guide

### Before (Manual Workaround)

```elixir
defp load_policies_from_db do
  rules = Repo.all(Acx.Persist.EctoAdapter.CasbinRule)

  Enum.each(rules, fn rule ->
    case rule.ptype do
      "p" ->
        attrs = build_attrs([rule.v0, rule.v1, rule.v2, rule.v3, rule.v4, rule.v5, rule.v6])
        EnforcerServer.add_policy(@enforcer_name, {:p, attrs})

      "g" ->
        attrs = build_attrs([rule.v0, rule.v1, rule.v2])
        case length(attrs) do
          3 ->
            [child, parent, domain] = attrs
            EnforcerServer.add_mapping_policy(@enforcer_name, {:g, child, parent, domain})
          2 ->
            [child, parent] = attrs
            EnforcerServer.add_mapping_policy(@enforcer_name, {:g, child, parent})
        end
    end
  end)
end

defp build_attrs(values) do
  Enum.reject(values, &is_nil/1)
end
```

### After (Clean API)

```elixir
# Set up adapter
adapter = EctoAdapter.new(Repo)
EnforcerServer.set_persist_adapter("my_enforcer", adapter)

# Load all policies from database
EnforcerServer.load_policies("my_enforcer")
EnforcerServer.load_mapping_policies("my_enforcer")
```

## Backward Compatibility

The new functions are fully backward compatible:

- `load_policies/2` still works with file paths
- `load_mapping_policies/2` still works with file paths
- All existing code continues to work without modification
- The new `/1` variants are optional and can be adopted gradually

## Related Functions

- `EnforcerServer.set_persist_adapter/2` - Configure the adapter
- `EnforcerServer.load_filtered_policies/2` - Load with filters
- `EnforcerServer.save_policies/1` - Save all policies to adapter
- `Enforcer.load_policies!/1` - Low-level API for direct enforcer usage

defmodule Acx.Enforcer do
  @moduledoc """
  TODO
  """

  defstruct model: nil,
            policies: [],
            mapping_policies: [],
            role_groups: [],
            env: %{},
            persist_adapter: nil

  alias Acx.Model
  alias Acx.Internal.RoleGroup
  alias Acx.Persist.PersistAdapter

  @type mapping() :: {atom(), String.t(), String.t()} |
                     {atom(), String.t(), String.t(), String.t()}

  @type t() :: %__MODULE__{
          model: Model.t(),
          policies: [Model.Policy.t()],
          mapping_policies: [String.t()],
          role_groups: %{atom() => RoleGroup.t()},
          env: map(),
          persist_adapter: PersistAdapter.t()
        }



  @doc """
  Loads and contructs a model from the given config file `cfile`.
  """
  @spec init(String.t(), PersistAdapter.t()) :: {:ok, t()} | {:error, String.t()}
  def init(cfile, adapter) when is_binary(cfile) do
    case init(cfile) do
      {:error, reason} ->
        {:error, reason}

      {:ok, module} ->
        module = set_persist_adapter(module, adapter)
        {:ok, module}
    end
  end

  @doc """
  Loads and contructs a model from the given config file `cfile`.
  """
  @spec init(String.t()) :: {:ok, t()} | {:error, String.t()}
  def init(cfile) when is_binary(cfile) do
    case Model.init(cfile) do
      {:error, reason} ->
        {:error, reason}

      {:ok, %Model{role_mappings: role_mappings} = model} ->
        role_groups =
          role_mappings
          |> Enum.map(fn m -> {m, RoleGroup.new(m)} end)

        # TODO: What if one of the mapping name in `role_mappings`
        # conflicts with sone built-in function names?
        env =
          role_groups
          |> Enum.map(fn {name, g} -> {name, RoleGroup.stub_2(g)} end)
          |> Map.new()
          |> Map.merge(init_env())

        {
          :ok,
          %__MODULE__{
            model: model,
            role_groups: role_groups |> Map.new(),
            persist_adapter: Acx.Persist.ReadonlyFileAdapter.new(),
            env: env
          }
        }
    end
  end

  @doc """
  Returns `true` if `request` is allowed, otherwise `false`.
  """
  @spec allow?(t(), [String.t()]) :: boolean()
  def allow?(%__MODULE__{model: model} = e, request) when is_list(request) do
    matched_policies = list_matched_policies(e, request)
    Model.allow?(model, matched_policies)
  end

  #
  # Policy management.
  #

  @doc """
  Adds a new policy rule with key given by `key` and a list of
  attribute values `attr_values` to the enforcer.
  """
  @spec add_policy(t(), {atom(), [String.t()]}) :: t() | {:error, String.t()}
  def add_policy(
      %__MODULE__{persist_adapter: adapter} = enforcer,
      {_key, _attrs} = rule
    ) do
    with  {:ok, enforcer} <- load_policy(enforcer, rule),
          {:ok, adapter} <- PersistAdapter.add_policy(adapter, rule) do
      %{enforcer | persist_adapter: adapter}
    else
      {:error, reason} -> {:error, reason}
      true -> {:error, :already_existed}
    end
  end

  @doc """
  Adds a new policy rule with key given by `key` and a list of attribute
  values `attr_values` to the enforcer.
  """
  def add_policy!(%__MODULE__{} = enforcer, {key, attrs}) do
    case add_policy(enforcer, {key, attrs}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  @spec load_policy(t(), {atom(), [String.t()]}) :: t() | {:error, String.t()}
  defp load_policy(
      %__MODULE__{model: model, policies: policies, persist_adapter: adapter} = enforcer,
      {key, attrs}
    ) do
    with  {:ok, policy} <- Model.create_policy(model, {key, attrs}),
          false <- Enum.member?(policies, policy) do
            enforcer = %{enforcer | policies: [policy | policies], persist_adapter: adapter}
      {:ok, enforcer}
    else
      {:error, reason} -> {:error, reason}
      true -> {:error, :already_existed}
    end
  end

  defp load_policy!(%__MODULE__{} = enforcer, {key, attrs}) do
    case load_policy(enforcer, {key, attrs}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      {:ok, enforcer} ->
        enforcer
    end
  end

  @doc """
  Removes the policy rule or rules that match from the enforcer.
  """
  def remove_policy(
    %__MODULE__{model: model, policies: policies, persist_adapter: adapter} = enforcer,
    {key, attrs}
  ) do
    with {:ok, policy} <- Model.create_policy(model, {key, attrs}),
          true <- Enum.member?(policies, policy),
          {:ok, _adapter} <- PersistAdapter.remove_policy(adapter, {key, attrs}),
          policies <- Enum.reject(policies, fn p -> p == policy end) do
      %{enforcer | policies: policies}
    else
      false -> {:error, :nonexistent}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec remove_policy!(any, any) :: t()
  def remove_policy!(%__MODULE__{} = enforcer, {key, attrs}) do
    case remove_policy(enforcer, {key, attrs}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  @doc """
  Removes policies with attributes that match the filter fields
  starting at the index.any()

    # Examples
        iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
        ...> {:ok, e} = Enforcer.init(cfile)
        ...> e = Enforcer.add_policy(e, {:p, ["admin", "blog_post", "write"]})
        ...> e = Enforcer.add_policy(e, {:p, ["reader", "blog_post", "read"]})
        ...> e = Enforcer.add_policy(e, {:p, ["admin", "blog_post", "delete"]})
        ...> e = Enforcer.remove_filtered_policy(e, :p, 0, ["admin"])
        ...> Enforcer.list_policies(e)
        [
          %Acx.Model.Policy{
            key: :p,
            attrs: [sub: "reader", obj: "blog_post", act: "read", eft: "allow"]
          }
        ]


        iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
        ...> {:ok, e} = Enforcer.init(cfile)
        ...> e = Enforcer.add_policy(e, {:p, ["admin", "blog_post", "write"]})
        ...> e = Enforcer.add_policy(e, {:p, ["reader", "blog_post", "read"]})
        ...> e = Enforcer.add_policy(e, {:p, ["admin", "blog_post", "delete"]})
        ...> e = Enforcer.add_policy(e, {:p, ["reader", "comment", "read"]})
        ...> e = Enforcer.remove_filtered_policy(e, :p, 1, ["blog_post"])
        ...> Enforcer.list_policies(e)
        [
          %Acx.Model.Policy{
            key: :p,
            attrs: [sub: "reader", obj: "comment", act: "read", eft: "allow"]
          }
        ]
  """
  @spec remove_filtered_policy(t(), atom(), integer(), keyword()) :: t() | {:error, any()}
  def remove_filtered_policy(
    %__MODULE__{policies: policies, persist_adapter: adapter} = enforcer,
    req_key, idx, req
  )
    when is_atom(req_key) and is_integer(idx) and is_list(req) do
      filtered_policies =
        policies
        |> Enum.reject(fn %{key: key, attrs: attrs} ->
          attr_values =
            attrs
            |> Enum.map(&elem(&1, 1))
            |> Enum.slice(idx, length(req))

          [key | attr_values] === [req_key | req]
        end)

      {:ok, adapter} = PersistAdapter.remove_filtered_policy(adapter, req_key, idx, req)
      %{enforcer | policies: filtered_policies, persist_adapter: adapter}
  end

  @spec remove_filtered_policy!(t(), atom(), integer(), keyword()) :: t() | {:error, any()}
  def remove_filtered_policy!(
        %__MODULE__{} = enforcer,
        req_key, idx, req
      )
      when is_atom(req_key) and is_integer(idx) and is_list(req) do
    case remove_filtered_policy(enforcer, req_key, idx, req) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  @doc """
  Sets the provided adapter to manage persisting rules in storage.
  """
  def set_persist_adapter(%__MODULE__{} = enforcer, adapter) do
    %{enforcer | persist_adapter: adapter}
  end

  @doc """
  Loads policy rules from external file given by the name `pfile` and
  adds them to the enforcer.

  A valid policy file should be a `*.csv` file, in which each line must
  have the following format:

    `pkey, attr1, attr2, attr3`

  in which `pkey` is the key of the policy rule, this key must match the
  policy definition in the enforcer. `attr1`, `attr2`, ... are the
  value of attributes specified in the policy definition.

  ## Examples

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> pfile = "../../test/data/acl.csv" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.load_policies!(pfile)
      ...> %Enforcer{policies: policies} = e
      ...> policies
      [
      %Acx.Model.Policy{
        attrs: [sub: "peter", obj: "blog_post", act: "read", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "peter", obj: "blog_post", act: "modify", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "bob", obj: "blog_post", act: "read", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "alice", obj: "blog_post", act: "read", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "alice", obj: "blog_post", act: "modify", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "alice", obj: "blog_post", act: "delete", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "alice", obj: "blog_post", act: "create", eft: "allow"],
        key: :p
      }
      ]
  """

  @spec load_policies!(t()) :: t() | {:error, any()}
  def load_policies!(%__MODULE__{persist_adapter: nil}) do
    {:error, "No adapter set and no policy file provided"}
  end

  @spec load_policies!(t()) :: t() | {:error, any()}
  def load_policies!(%__MODULE__{model: m, persist_adapter: adapter} = enforcer) do
    case PersistAdapter.load_policies(adapter) do
      {:ok, policies} -> policies
        |> Enum.map(fn [key | attrs] -> [String.to_atom(key) | attrs] end)
        |> Enum.filter(fn [key | _] -> Model.has_policy_key?(m, key) end)
        |> Enum.map(fn [key | attrs] -> {key, attrs} end)
        |> Enum.reduce(enforcer, &load_policy!(&2, &1))
    end
  end

  @spec load_policies!(t(), String.t()) :: t()
  def load_policies!(%__MODULE__{model: m} = enforcer, pfile)
      when is_binary(pfile) do
        adapter = Acx.Persist.ReadonlyFileAdapter.new(pfile)
        enforcer = %{enforcer | persist_adapter: adapter}

        case PersistAdapter.load_policies(adapter) do
          {:ok, policies} -> policies
            |> Enum.map(fn [key | attrs] -> [String.to_atom(key) | attrs] end)
            |> Enum.filter(fn [key | _] -> Model.has_policy_key?(m, key) end)
            |> Enum.map(fn [key | attrs] -> {key, attrs} end)
            |> Enum.reduce(enforcer, &load_policy!(&2, &1))
    end
  end

  @doc """
  Returns a list of policies in the given enforcer that match the
  given criteria.

  For example, in order to get all policy rules with the key `:p`
  and the `act` attribute is `"read"`, you can call `list_policies/2`
  function with second argument:

  `%{key: :p, act: "read"}`

  By passing in an empty map or an empty list to the second argument
  of the function `list_policies/2`, you'll effectively get all policy
  rules in the enforcer (without filtered).

  ## Examples

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> pfile = "../../test/data/acl.csv" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.load_policies!(pfile)
      ...> e |> Enforcer.list_policies(%{sub: "peter"})
      [
      %Acx.Model.Policy{
        attrs: [sub: "peter", obj: "blog_post", act: "read", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "peter", obj: "blog_post", act: "modify", eft: "allow"],
        key: :p
      },
      %Acx.Model.Policy{
        attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"],
        key: :p
      }
      ]
  """
  @spec list_policies(t(), map() | keyword()) :: [Model.Policy.t()]
  def list_policies(
        %__MODULE__{policies: policies},
        criteria
      )
      when is_map(criteria) or is_list(criteria) do
    policies
    |> Enum.filter(fn %{key: key, attrs: attrs} ->
      list = [{:key, key} | attrs]
      criteria |> Enum.all?(fn c -> c in list end)
    end)
  end

  def list_policies(%__MODULE__{policies: policies}), do: policies

  @doc """
  Returns a list of policy rules in the given enforcer that match the
  given `request`.
  """
  @spec list_matched_policies(t(), [String.t()]) :: [Model.Policy.t()]
  def list_matched_policies(
        %__MODULE__{model: model, policies: policies, env: env},
        request
      )
      when is_list(request) do
    case Model.create_request(model, request) do
      {:error, _reason} ->
        []

      {:ok, req} ->
        policies
        |> Enum.filter(fn pol -> Model.match?(model, req, pol, env) end)
    end
  end

  #
  # RBAC role management
  #

  @spec load_mapping_policy(t(), {atom(), String.t(), String.t()}) ::
  t() | {:error, String.t()}
  defp load_mapping_policy(
        %__MODULE__{
          mapping_policies: mappings,
          role_groups: groups,
          env: env,
          persist_adapter: adapter
        } = enforcer,
        {mapping_name, role1, role2} = mapping
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) do
        with group when not is_nil(group) <- Map.get(groups, mapping_name),
            false <- Enum.member?(mappings, mapping),
            group <- RoleGroup.add_inheritance(group, {role1, role2}) do
        new_enforcer = %{
          enforcer
          | role_groups: %{groups | mapping_name => group},
            mapping_policies: [mapping | mappings],
            persist_adapter: adapter,
            env: %{env | mapping_name => RoleGroup.stub_2(group)}
        }
        {:ok, new_enforcer}
      else
        nil ->
          {:error, "mapping name not found: `#{mapping_name}`"}
        true ->
          {:error, :already_existed}
    end
  end

  @spec load_mapping_policy(t(), {atom(), String.t(), String.t(), String.t()}) ::
  t() | {:error, String.t()}
  defp load_mapping_policy(
        %__MODULE__{
          mapping_policies: mappings,
          role_groups: groups,
          env: env,
          persist_adapter: adapter
        } = enforcer,
        {mapping_name, role1, role2, dom} = mapping
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) and is_binary(dom) do
        with group when not is_nil(group) <- Map.get(groups, mapping_name),
            false <- Enum.member?(mappings, mapping),
            group <- RoleGroup.add_inheritance(group, {role1, role2 <> dom}) do
          new_enforcer = %{
            enforcer
            | role_groups: %{groups | mapping_name => group},
            mapping_policies: [mapping | mappings],
              persist_adapter: adapter,
              env: %{env | mapping_name => RoleGroup.stub_3(group)}
          }
          {:ok, new_enforcer}
        else
          nil ->
            {:error, "mapping name not found: `#{mapping_name}`"}
          true ->
            {:error, :already_existed}
    end
  end

  defp load_mapping_policy!(
        %__MODULE__{} = enforcer,
        {mapping_name, role1, role2}
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) do
    case load_mapping_policy(enforcer, {mapping_name, role1, role2}) do
      {:error, :already_existed} ->
        enforcer

      {:error, reason} ->
        raise ArgumentError, message: reason

      {:ok, enforcer} ->
        enforcer
    end
  end

  defp load_mapping_policy!(
        %__MODULE__{} = enforcer,
        {mapping_name, role1, role2, dom}
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) and is_binary(dom) do
    case load_mapping_policy(enforcer, {mapping_name, role1, role2, dom}) do
      {:error, :already_existed} ->
        enforcer

      {:error, reason} ->
        raise ArgumentError, message: reason

      {:ok, enforcer} ->
        enforcer
    end
  end


  @doc """
  Makes `role1` inherit from (or has role ) `role2`. The `mapping_name`
  should be one of the names given in the model configuration file under
  the `role_definition` section. For example if your role definition look
  like this:

    [role_definition]
    g = _, _

  then `mapping_name` should be the atom `:g`.

  ## Examples

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.add_mapping_policy({:g, "bob", "admin"})
      ...> %Enforcer{env: %{g: g}} = e
      ...> false = g.("admin", "bob")
      ...> g.("bob", "admin")
      true

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.add_mapping_policy({:g, "bob", "admin"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "admin", "author"})
      ...> %Enforcer{env: %{g: g}} = e
      ...> g.("bob", "author")
      true

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> invalid_mapping = {:g2, "bob", "admin"}
      ...> {:error, msg} = e |> Enforcer.add_mapping_policy(invalid_mapping)
      ...> msg
      "mapping name not found: `g2`"

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.add_mapping_policy({:g, "bob", "admin"})
      ...> e |> Enforcer.add_mapping_policy({:g, "bob", "admin"})
      {:error, :already_existed}
  """
  @spec add_mapping_policy(t(), {atom(), String.t(), String.t()}) ::
          t() | {:error, String.t()}
  def add_mapping_policy(
        %__MODULE__{persist_adapter: adapter} = enforcer,
        {mapping_name, role1, role2} = mapping
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) do
        with {:ok, new_enforcer} <- load_mapping_policy(enforcer, mapping),
            {:ok, adapter} <- PersistAdapter.add_policy(adapter, {mapping_name, [role1, role2]}) do
        %{new_enforcer | persist_adapter: adapter}
      else
        {:error, reason} ->
          {:error, reason}
    end
  end

  def add_mapping_policy(
        %__MODULE__{persist_adapter: adapter} = enforcer,
        {mapping_name, role1, role2, dom} = mapping
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) and is_binary(dom) do
        with {:ok, new_enforcer} <- load_mapping_policy(enforcer, mapping),
             {:ok, adapter} <- PersistAdapter.add_policy(adapter, {mapping_name, [role1, role2, dom]}) do
              %{new_enforcer | persist_adapter: adapter}
        else
          {:error, reason} ->
            {:error, reason}
    end
  end


  def add_mapping_policy!(
        %__MODULE__{} = enforcer,
        {mapping_name, role1, role2}
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) do
    case add_mapping_policy(enforcer, {mapping_name, role1, role2}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  def add_mapping_policy!(
        %__MODULE__{} = enforcer,
        {mapping_name, role1, role2, dom}
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) and is_binary(dom) do
    case add_mapping_policy(enforcer, {mapping_name, role1, role2, dom}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  @doc """
  Loads mapping policies from the persist adapter and adds them to the enforcer.
  """
  def load_mapping_policies!(%__MODULE__{model: m, persist_adapter: adapter} = enforcer) do
    case PersistAdapter.load_policies(adapter) do
      {:ok, policies} -> policies
      |> Enum.map(fn [key | attrs] -> [String.to_atom(key) | attrs] end)
      |> Enum.filter(fn [key | _] -> Model.has_role_mapping?(m, key) end)
      |> Enum.map(fn
          [name, r1, r2] -> {name, r1, r2}
          [name, r1, r2, d] -> {name, r1, r2, d}
        end)
      |> Enum.reduce(enforcer, &load_mapping_policy!(&2, &1))
    end
  end

  @doc """
  Loads mapping policies from a csv file and adds them to the enforcer.

  A valid mapping policies file must be a `*.csv` file and each line of
  that file should have the following format:

    `mapping_name, role1, role2`

  where `mapping_name` is one of the names given in the config file under
  the role definition section.

  Note that you don't have to have a separate mapping policies file, instead
  you could just put all of your mapping policies inside your policy rules
  file.
  """
  def load_mapping_policies!(%__MODULE__{model: m} = enforcer, fname)
      when is_binary(fname) do
    fname
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.split(&1, ~r{,\s*}))
    |> Enum.map(fn [key | attrs] -> [String.to_atom(key) | attrs] end)
    |> Enum.filter(fn [key | _] -> Model.has_role_mapping?(m, key) end)
    |> Enum.map(fn
      [name, r1, r2] -> {name, r1, r2}
      [name, r1, r2, d] -> {name, r1, r2, d}
    end)
    |> Enum.reduce(enforcer, &load_mapping_policy!(&2, &1))
  end

  @doc """
  Removes the connection of the role to the permission and its corresponding
  mapping policy from storage.
  """
  @spec remove_mapping_policy(t(), {atom(), String.t(), String.t()}) :: t() | {:error, String.t()}
  def remove_mapping_policy(
        %__MODULE__{mapping_policies: mappings, role_groups: groups, env: env, persist_adapter: adapter} = enforcer,
        {mapping_name, role1, role2} = mapping
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) do
        with group when not is_nil(group) <- Map.get(groups, mapping_name),
            group <- RoleGroup.remove_inheritance(group, {role1, role2}),
            mappings <- Enum.reject(mappings, fn m -> m == mapping end),
            {:ok, adapter} <- PersistAdapter.remove_policy(adapter, {mapping_name, [role1, role2]}) do
        %{
          enforcer
          | role_groups: %{groups | mapping_name => group},
            mapping_policies: mappings,
            persist_adapter: adapter,
            env: %{env | mapping_name => RoleGroup.stub_2(group)}
        }
      else
        nil ->
          {:error, "mapping name not found: `#{mapping_name}`"}
    end
  end

  @spec remove_mapping_policy(t(), {atom(), String.t(), String.t(), String.t()}) :: t() | {:error, String.t()}
  def remove_mapping_policy(
        %__MODULE__{mapping_policies: mappings, role_groups: groups, env: env, persist_adapter: adapter} = enforcer,
        {mapping_name, role1, role2, dom} = mapping
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) and is_binary(dom) do
        with group when not is_nil(group) <- Map.get(groups, mapping_name),
             group <- RoleGroup.remove_inheritance(group, {role1, role2 <> dom}),
             mappings <- Enum.reject(mappings, fn m -> m == mapping end),
             {:ok, _adpater} <- PersistAdapter.remove_policy(adapter, {mapping_name, [role1, role2, dom]}) do
          %{
            enforcer
            | role_groups: %{groups | mapping_name => group},
              mapping_policies: mappings,
              persist_adapter: adapter,
              env: %{env | mapping_name => RoleGroup.stub_3(group)}
          }
        else
          nil ->
            {:error, "mapping name not found: `#{mapping_name}`"}
    end
  end

  def remove_mapping_policy!(
        %__MODULE__{} = enforcer,
        {mapping_name, role1, role2}
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) do
    case remove_mapping_policy(enforcer, {mapping_name, role1, role2}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  def remove_mapping_policy!(
        %__MODULE__{} = enforcer,
        {mapping_name, role1, role2, dom}
      )
      when is_atom(mapping_name) and is_binary(role1) and is_binary(role2) and is_binary(dom) do
    case remove_mapping_policy(enforcer, {mapping_name, role1, role2, dom}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      enforcer ->
        enforcer
    end
  end

  @doc """
  Lists mapping policies and can take a filter that matches any position
  or displaced filter that matches positionally

  ## Examples

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.add_mapping_policy({:g, "author", "reader"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "admin", "author"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "bob", "admin"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "alice", "author"})
      ...> Enforcer.list_mapping_policies(e, ["author"])
      [
        {:g, "alice", "author"},
        {:g, "admin", "author"},
        {:g, "author", "reader"}
      ]

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.add_mapping_policy({:g, "author", "reader"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "admin", "author"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "bob", "admin"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "alice", "author"})
      ...> Enforcer.list_mapping_policies(e, 2, ["author"])
      [
        {:g, "alice", "author"},
        {:g, "admin", "author"}
      ]

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> e = e |> Enforcer.add_mapping_policy({:g, "author", "reader"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "admin", "author"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "bob", "admin"})
      ...> e = e |> Enforcer.add_mapping_policy({:g, "alice", "author"})
      ...> Enforcer.list_mapping_policies(e, 1, ["admin", "author"])
      [
        {:g, "admin", "author"}
      ]
  """
  @spec list_mapping_policies(t(), integer(), keyword()) :: [mapping()]
  def list_mapping_policies(
    %__MODULE__{mapping_policies: mapping_policies},
    idx,
    criteria
  ) when is_list(criteria) and is_integer(idx) do
    mapping_policies
    |> Enum.filter(fn mapping ->
      Tuple.to_list(mapping)
      |> Enum.slice(idx, length(criteria))
      |> Kernel.==(criteria)
    end)
  end

  @spec list_mapping_policies(Acx.Enforcer.t(), maybe_improper_list) :: [mapping()]
  def list_mapping_policies(
    %__MODULE__{mapping_policies: mapping_policies},
    criteria
  ) when is_list(criteria) do
    mapping_policies
    |> Enum.filter(fn mapping ->
      list = Tuple.to_list(mapping)
      criteria |> Enum.all?(fn c -> c in list end)
    end)
  end

  @spec list_mapping_policies(Acx.Enforcer.t()) :: [mapping()]
  def list_mapping_policies(%__MODULE__{mapping_policies: mapping_policies}), do: mapping_policies

  @doc """
  Saves the updated list of policies using the configured PersistAdapter. This function
  is useful for adapters that don't do incremental add/removes for policies or for loading
  policies from one source and saving to another after changing adapters.
  """
  def save_policies(
    %__MODULE__{persist_adapter: adapter, policies: policies, mapping_policies: mapping_policies} = enforcer
    ) do
    policies =  mapping_policies
    |> Enum.map(&Tuple.to_list(&1))
    |> Enum.map(fn [key | attrs] -> %{key: key, attrs: attrs} end)
    |> Enum.concat(policies)

    case PersistAdapter.save_policies(adapter, policies) do
      {:error, errors} -> {:error, errors}
      adapter -> %{enforcer | persist_adapter: adapter}
    end
  end

  def save_policies!(%__MODULE__{} = enforcer) do
    case save_policies(enforcer) do
      {:error, _} ->
        raise RuntimeError, message: "save failed"

      enforcer ->
        enforcer
    end
  end

  #
  # User defined function.
  #

  @doc """
  Adds a user-defined function to the enforcer.

  Like built-in function `regex_match?/2`, you can define your own
  function and add it to the enforcer to use in your matcher expression.
  Note that the `fun_name` must match the name used in the matcher
  expression.

  ## Examples

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, e} = Enforcer.init(cfile)
      ...> my_fun = fn x, y -> x + y end
      ...> e = e |> Enforcer.add_fun({:my_fun, my_fun})
      ...> %Enforcer{env: %{my_fun: f}} = e
      ...> f.(1, 2)
      3
  """
  @spec add_fun(t(), {atom(), function()}) :: t()
  def add_fun(%__MODULE__{env: env} = enforcer, {fun_name, fun})
      when is_atom(fun_name) and is_function(fun) do
    %{enforcer | env: Map.put(env, fun_name, fun)}
  end

  #
  # Build in stubs function
  #

  @doc """
  Returns `true` if the given string `str` matches the pattern
  string `^pattern$`.

  Returns `false` otherwise.

  ## Examples

      iex> Enforcer.regex_match?("/alice_data/foo", "/alice_data/.*")
      true
  """
  @spec regex_match?(String.t(), String.t()) :: boolean()
  def regex_match?(str, pattern) do
    case Regex.compile("^#{pattern}$") do
      {:error, _} ->
        false

      {:ok, r} ->
        Regex.match?(r, str)
    end
  end

  @doc """
  Returns `true` if `key1` matches the pattern of `key2`.

  Returns `false` otherwise.

  `key_match2?/2` can handle three types of path / patterns :

    URL path like `/alice_data/resource1`.
    `:` pattern like `/alice_data/:resource`.
    `*` pattern like `/alice_data/*`.

  ## Parameters

  - `key1` should be a URL path.
  - `key2` can be a URL path, a `:` pattern or a `*` pattern.

  ## Examples

      iex> Enforcer.key_match2?("alice_data/resource1", "alice_data/*")
      true
      iex> Enforcer.key_match2?("alice_data/resource1", "alice_data/:resource")
      true
  """
  @spec key_match2?(String.t(), String.t()) :: boolean()
  def key_match2?(key1, key2) do
    key2 = String.replace(key2, "/*", "/.*")

    with {:ok, r1} <- Regex.compile(":[^/]+"),
         match <- Regex.replace(r1, key2, "[^/]+"),
         {:ok, r2} <- Regex.compile("^" <> match <> "$") do
      Regex.match?(r2, key1)
    else
      _ -> false
    end
  end

  #
  # Helpers
  #

  defp init_env do
    %{
      regexMatch: &regex_match?/2,
      keyMatch2: &key_match2?/2
    }
  end
end

defmodule Acx.Persist.EctoAdapter do
  @moduledoc """
  This module defines an adapter for persisting the list of policies
  to a database.
  """
  import Ecto.Changeset
  use Ecto.Schema

  defstruct repo: nil

  defmodule CasbinRule do
    @moduledoc """
    Schema for storing Casbin rules in the database.
    """
    import Ecto.Changeset
    require Ecto.Query
    use Ecto.Schema
    @columns [:ptype, :v0, :v1, :v2, :v3, :v4, :v5, :v6]

    schema "casbin_rule" do
      field(:ptype, :string)
      field(:v0, :string)
      field(:v1, :string)
      field(:v2, :string)
      field(:v3, :string)
      field(:v4, :string)
      field(:v5, :string)
      field(:v6, :string)
    end

    @doc """

      # Examples
        iex> CasbinRule.policy_to_map({:p, ["admin"]}, 1) |> Map.to_list |> Enum.sort
        [ptype: "p", v1: "admin"]


        iex> CasbinRule.policy_to_map({:p, ["admin"]}) |> Map.to_list |> Enum.sort
        [ptype: "p", v0: "admin"]

    """
    @spec policy_to_map({atom(), [String.t()]}) :: %{}
    def policy_to_map({key, attrs}) do
      Enum.zip(@columns, [Atom.to_string(key) | attrs]) |> Map.new()
    end

    def policy_to_map({key, attrs}, idx) do
      [kcol | cols] = @columns

      arr =
        cols
        |> Enum.slice(idx, length(attrs))
        |> (&[&2 | &1]).(kcol)
        |> Enum.zip([Atom.to_string(key) | attrs])
        |> Map.new()

      arr
    end

    @spec create_changeset({atom(), [String.t()]}) :: Ecto.Changeset.t()
    def create_changeset({_key, _attrs} = policy) do
      changeset(%CasbinRule{}, policy_to_map(policy))
    end

    @spec create_changeset(
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t()
          ) :: Ecto.Changeset.t()
    def create_changeset(ptype, v0, v1, v2 \\ nil, v3 \\ nil, v4 \\ nil, v5 \\ nil, v6 \\ nil) do
      changeset(%CasbinRule{}, %{
        ptype: ptype,
        v0: v0,
        v1: v1,
        v2: v2,
        v3: v3,
        v4: v4,
        v5: v5,
        v6: v6
      })
    end

    def changeset(rule, params \\ %{}) do
      rule
      |> cast(params, @columns)
      |> validate_required([:ptype, :v0, :v1])
    end

    def changeset_to_list(%{ptype: ptype, v0: v0, v1: v1, v2: v2, v3: v3, v4: v4, v5: v5, v6: v6}) do
      [ptype, v0, v1, v2, v3, v4, v5, v6] |> Enum.filter(fn a -> !Kernel.is_nil(a) end)
    end

    def changeset_to_queryable({_key, _attrs} = policy, idx) do
      arr =
        policy_to_map(policy, idx)
        |> Map.to_list()

      Ecto.Query.from(CasbinRule, where: ^arr)
    end

    def changeset_to_queryable({key, attrs}) do
      arr = Enum.zip(@columns, [Atom.to_string(key) | attrs])
      Ecto.Query.from(CasbinRule, where: ^arr)
    end
  end

  def new(repo) do
    %__MODULE__{repo: repo}
  end

  defimpl Acx.Persist.PersistAdapter, for: Acx.Persist.EctoAdapter do
    @doc """
    Queries the list of policy rules from the database and returns them
    as a list of strings.

    ## Examples

        iex> PersistAdapter.load_policies(%Acx.Persist.EctoAdapter{repo: nil})
        ...> {:error, "repo is not set"}
    """
    @spec load_policies(EctoAdapter.t()) :: [Model.Policy.t()]
    def load_policies(%Acx.Persist.EctoAdapter{repo: nil}) do
      {:error, "repo is not set"}
    end

    def load_policies(adapter) do
      policies =
        adapter.repo.all(CasbinRule)
        |> Enum.map(&CasbinRule.changeset_to_list(&1))

      {:ok, policies}
    end

    @doc """
    Loads only policies matching the given filter from the database.

    The filter is a map where keys can be `:ptype`, `:v0`, `:v1`, `:v2`, `:v3`, `:v4`, `:v5`, or `:v6`.
    Values can be either a single string or a list of strings for matching multiple values.

    ## Examples

        # Load policies for a specific domain
        filter = %{v3: "org:tenant_123"}
        PersistAdapter.load_filtered_policy(adapter, filter)

        # Load policies with multiple criteria
        filter = %{ptype: "p", v3: ["org:tenant_1", "org:tenant_2"]}
        PersistAdapter.load_filtered_policy(adapter, filter)

        iex> PersistAdapter.load_filtered_policy(%Acx.Persist.EctoAdapter{repo: nil}, %{})
        ...> {:error, "repo is not set"}
    """
    @spec load_filtered_policy(EctoAdapter.t(), map()) :: {:ok, [list()]} | {:error, String.t()}
    def load_filtered_policy(%Acx.Persist.EctoAdapter{repo: nil}, _filter) do
      {:error, "repo is not set"}
    end

    def load_filtered_policy(adapter, filter) when is_map(filter) do
      query = build_filtered_query(filter)

      policies =
        adapter.repo.all(query)
        |> Enum.map(&CasbinRule.changeset_to_list(&1))

      {:ok, policies}
    end

    defp build_filtered_query(filter) do
      import Ecto.Query
      base_query = from(r in CasbinRule)

      Enum.reduce(filter, base_query, fn {field, value}, query ->
        add_where_clause(query, field, value)
      end)
    end

    # Helper function to add WHERE clause for a single filter condition
    defp add_where_clause(query, field, values) when is_list(values) do
      import Ecto.Query

      case field do
        :ptype -> where(query, [r], r.ptype in ^values)
        :v0 -> where(query, [r], r.v0 in ^values)
        :v1 -> where(query, [r], r.v1 in ^values)
        :v2 -> where(query, [r], r.v2 in ^values)
        :v3 -> where(query, [r], r.v3 in ^values)
        :v4 -> where(query, [r], r.v4 in ^values)
        :v5 -> where(query, [r], r.v5 in ^values)
        :v6 -> where(query, [r], r.v6 in ^values)
        _ -> query
      end
    end

    defp add_where_clause(query, field, value) do
      import Ecto.Query

      case field do
        :ptype -> where(query, [r], r.ptype == ^value)
        :v0 -> where(query, [r], r.v0 == ^value)
        :v1 -> where(query, [r], r.v1 == ^value)
        :v2 -> where(query, [r], r.v2 == ^value)
        :v3 -> where(query, [r], r.v3 == ^value)
        :v4 -> where(query, [r], r.v4 == ^value)
        :v5 -> where(query, [r], r.v5 == ^value)
        :v6 -> where(query, [r], r.v6 == ^value)
        _ -> query
      end
    end

    @doc """
    Uses the configured repo to insert a Policy into the casbin_rule table.

    Returns an error if repo is not set.

    ## Examples

        iex> PersistAdapter.add_policy(
        ...>    %Acx.Persist.EctoAdapter{},
        ...>    {:p, ["user", "file", "read"]})
        ...> {:error, "repo is not set"}
    """
    def add_policy(%Acx.Persist.EctoAdapter{repo: nil}, _) do
      {:error, "repo is not set"}
    end

    def add_policy(
          %Acx.Persist.EctoAdapter{repo: repo} = adapter,
          {_key, _attrs} = policy
        ) do
      changeset = CasbinRule.create_changeset(policy)

      case repo.insert(changeset) do
        {:ok, _casbin} -> {:ok, adapter}
        {:error, changeset} -> {:error, changeset.errors}
      end
    end

    @doc """
    Removes all rules matching the provided attributes. If a subset of attributes
    are provided it will remove all matching records, i.e. if only a subj is provided
    all records including that subject will be removed from storage

    Returns an error if repo is not set.

    ## Examples

        iex> PersistAdapter.remove_policy(
        ...>    %Acx.Persist.EctoAdapter{},
        ...>    {:p, ["user", "file", "read"]})
        ...> {:error, "repo is not set"}
    """
    def remove_policy(%Acx.Persist.EctoAdapter{repo: nil}, _) do
      {:error, "repo is not set"}
    end

    def remove_policy(
          %Acx.Persist.EctoAdapter{repo: repo} = adapter,
          {_key, _attr} = policy
        ) do
      f = CasbinRule.changeset_to_queryable(policy)

      case repo.delete_all(f) do
        {:error, changeset} -> {:error, changeset.errors}
        _ -> {:ok, adapter}
      end
    end

    def remove_filtered_policy(
          %Acx.Persist.EctoAdapter{repo: repo} = adapter,
          key,
          idx,
          attrs
        ) do
      f = CasbinRule.changeset_to_queryable({key, attrs}, idx)

      case repo.delete_all(f) do
        {:error, changeset} -> {:error, changeset.errors}
        _ -> {:ok, adapter}
      end
    end

    @doc """
    Truncates the table and inserts the provided policies.

    Returns an error if repo is not set.

    ## Examples

        iex> PersistAdapter.save_policies(
        ...>    %Acx.Persist.EctoAdapter{},
        ...>    [])
        ...> {:error, "repo is not set"}
    """
    def save_policies(%Acx.Persist.EctoAdapter{repo: nil}, _) do
      {:error, "repo is not set"}
    end

    def save_policies(
          %Acx.Persist.EctoAdapter{repo: repo} = adapter,
          policies
        ) do
      repo.transaction(fn -> insert_policies(repo, adapter, policies) end)
    end

    defp insert_policies(repo, adapter, policies) do
      repo.delete_all(CasbinRule)
      Enum.each(policies, &insert_policy(repo, adapter, &1))
    end

    defp insert_policy(repo, adapter, policy) do
      changeset = CasbinRule.create_changeset(policy)

      case repo.insert(changeset) do
        {:ok, _casbin} -> adapter
        {:error, changeset} -> {:error, changeset.errors}
      end
    end
  end
end

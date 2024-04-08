defmodule Acx.Persist.EctoAdapter do
  @moduledoc """
  This module defines an adapter for persisting the list of policies
  to a database.
  """
  import Ecto.Changeset
  use Ecto.Schema

  defstruct repo: nil

  defmodule CasbinRule do
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
        iex> CasbinRule.policy_to_map({:p, ["admin"]}, 1) |> Map.to_list
        [ptype: "p", v1: "admin"]


        iex> CasbinRule.policy_to_map({:p, ["admin"]}) |> Map.to_list
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

    @spec create_changeset({atom(), [String.t()]}) :: %CasbinRule{}
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
          ) :: %CasbinRule{}
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
      repo.transaction(fn ->
        repo.delete_all(CasbinRule)

        Enum.each(policies, fn policy ->
          changeset = CasbinRule.create_changeset(policy)

          case repo.insert(changeset) do
            {:ok, _casbin} -> adapter
            {:error, changeset} -> {:error, changeset.errors}
          end
        end)
      end)
    end
  end
end

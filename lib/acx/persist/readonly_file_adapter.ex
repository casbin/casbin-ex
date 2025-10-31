defmodule Acx.Persist.ReadonlyFileAdapter do
  @moduledoc """
  A read-only file adapter for loading policies from files.
  """
  alias Acx.Persist.PersistAdapter

  defstruct policy_file: nil

  def new do
    %__MODULE__{policy_file: nil}
  end

  def new(pfile) do
    %__MODULE__{policy_file: pfile}
  end

  defimpl PersistAdapter, for: Acx.Persist.ReadonlyFileAdapter do
    def load_policies(%Acx.Persist.ReadonlyFileAdapter{policy_file: nil}) do
      {:ok, []}
    end

    def load_policies(adapter) do
      policies =
        adapter.policy_file
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ~r{,\s*}))

      {:ok, policies}
    end

    def load_policies(_adapter, pfile) do
      policies =
        File.read!(pfile)
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ~r{,\s*}))

      {:ok, policies}
    end

    @doc """
    Loads filtered policies from a file.

    The filter is applied in-memory after loading all policies.
    Note: For file-based adapters, filtering does not improve performance
    as all data must be read from disk anyway.

    ## Examples

        filter = %{ptype: "p", v3: "org:tenant_123"}
        PersistAdapter.load_filtered_policy(adapter, filter)
    """
    def load_filtered_policy(%Acx.Persist.ReadonlyFileAdapter{policy_file: nil}, _filter) do
      {:ok, []}
    end

    def load_filtered_policy(adapter, filter) when is_map(filter) do
      case load_policies(adapter) do
        {:ok, policies} ->
          filtered_policies = apply_filter(policies, filter)
          {:ok, filtered_policies}

        error ->
          error
      end
    end

    defp apply_filter(policies, filter) do
      Enum.filter(policies, fn policy ->
        matches_filter?(policy, filter)
      end)
    end

    defp matches_filter?(policy, filter) do
      Enum.all?(filter, fn {key, value} ->
        policy_value = get_policy_value(policy, key)
        matches_value?(policy_value, value)
      end)
    end

    defp get_policy_value([ptype | values], :ptype), do: ptype

    defp get_policy_value([_ptype | values], key) do
      index =
        case key do
          :v0 -> 0
          :v1 -> 1
          :v2 -> 2
          :v3 -> 3
          :v4 -> 4
          :v5 -> 5
          :v6 -> 6
          _ -> nil
        end

      if index && index < length(values) do
        Enum.at(values, index)
      else
        nil
      end
    end

    defp matches_value?(policy_value, filter_value) when is_list(filter_value) do
      policy_value in filter_value
    end

    defp matches_value?(policy_value, filter_value) do
      policy_value == filter_value
    end

    def add_policy(adapter, _policy) do
      {:ok, adapter}
    end

    def save_policies(adapter, _policies) do
      {:ok, adapter}
    end

    def remove_policy(adapter, _policy) do
      {:ok, adapter}
    end

    def remove_filtered_policy(adapter, _key, _idx, _attrs) do
      {:ok, adapter}
    end
  end
end

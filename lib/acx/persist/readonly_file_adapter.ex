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

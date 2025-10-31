defmodule Acx.Persist.MockRepo do
  @moduledoc """
  Mock repository for testing Ecto adapter functionality.
  """

  defmacro __using__(opts) do
    pfile = opts[:pfile]

    quote do
      alias Acx.Persist.EctoAdapter.CasbinRule
      alias Ecto.Changeset

      def to_changeset(id, rule) do
        Enum.zip([:ptype, :v0, :v1, :v2, :v3, :v4, :v5, :v6], rule)
        |> Map.new()
        |> then(&Map.merge(%Acx.Persist.EctoAdapter.CasbinRule{id: id}, &1))
      end

      def all(CasbinRule, _opts \\ []) do
        unquote(pfile)
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ~r{,\s*}))
        |> Enum.with_index(1)
        |> Enum.map(fn {rule, id} -> to_changeset(id, rule) end)
      end

      def all(%Ecto.Query{} = query, _opts \\ []) do
        # Get all policies first
        all_policies = all(CasbinRule)

        # Apply filters from the query's where clauses
        apply_query_filters(all_policies, query)
      end

      defp apply_query_filters(policies, %Ecto.Query{wheres: wheres}) do
        Enum.reduce(wheres, policies, fn where_clause, acc ->
          apply_where_clause(acc, where_clause)
        end)
      end

      defp apply_where_clause(policies, %{expr: expr}) do
        case expr do
          # Handle equality comparisons: field == value
          {:==, _, [{{:., _, [{:&, _, [0]}, field]}, _, _}, {:^, _, [idx]}]} ->
            value = get_binding_value(idx)
            Enum.filter(policies, fn policy ->
              Map.get(policy, field) == value
            end)

          # Handle 'in' comparisons: field in values
          {:in, _, [{{:., _, [{:&, _, [0]}, field]}, _, _}, {:^, _, [idx]}]} ->
            values = get_binding_value(idx)
            Enum.filter(policies, fn policy ->
              Map.get(policy, field) in values
            end)

          _ ->
            policies
        end
      end

      # This is a simplification - in real tests we'd need to track bindings
      # For now, we'll extract values from the query structure
      defp get_binding_value(idx) do
        # This is a mock - in a real scenario, bindings would be tracked
        # For testing purposes, we'll need to enhance this
        nil
      end

      def insert(changeset, opts \\ [])

      def insert(%Changeset{errors: [], changes: values}, _opts) do
        {:ok, struct(CasbinRule, values)}
      end

      def insert(changeset, _opts) do
        {:error, changeset}
      end

      def delete_all(queryset) do
        {1, nil}
      end

      # Allow override in using modules
      defoverridable all: 1, all: 2
    end
  end
end

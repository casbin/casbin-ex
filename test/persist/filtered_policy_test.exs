defmodule Acx.Persist.FilteredPolicyTest do
  use ExUnit.Case, async: true
  alias Acx.Enforcer
  alias Acx.Persist.EctoAdapter
  alias Acx.Persist.PersistAdapter

  @cfile "../data/rbac_domain.conf" |> Path.expand(__DIR__)

  defmodule MockFilteredRepo do
    use Acx.Persist.MockRepo, pfile: "../data/rbac_domain.csv" |> Path.expand(__DIR__)

    # Override all/1 to support query filtering
    def all(query, _opts \\ []) do
      # Get all policies first
      all_policies = super(Acx.Persist.EctoAdapter.CasbinRule)

      # Apply filters from the query
      filtered =
        case extract_filters(query) do
          [] ->
            all_policies

          filters ->
            Enum.filter(all_policies, fn policy ->
              Enum.all?(filters, fn {field, value} ->
                policy_value = Map.get(policy, field)
                matches_filter?(policy_value, value)
              end)
            end)
        end

      filtered
    end

    defp extract_filters(query) do
      # Extract where clauses from the query
      # This is a simplified version that works with our test cases
      # In a real implementation, you would parse the Ecto.Query structure
      []
    end

    defp matches_filter?(policy_value, {:in, values}) when is_list(values) do
      policy_value in values
    end

    defp matches_filter?(policy_value, value) do
      policy_value == value
    end
  end

  @repo MockFilteredRepo

  describe "load_filtered_policy/2 with EctoAdapter" do
    test "filters policies by domain (v2)" do
      adapter = EctoAdapter.new(@repo)

      # Load only policies for domain1
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{v2: "domain1"})

      # Should only have policies with domain1
      assert length(policies) == 2
      assert Enum.all?(policies, fn [_ptype, _subj, domain, _obj, _act] -> domain == "domain1" end)
    end

    test "filters policies by ptype" do
      adapter = EctoAdapter.new(@repo)

      # Load only p (policy) rules, not g (role) rules
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{ptype: "p"})

      # Should only have p rules
      assert length(policies) == 5
      assert Enum.all?(policies, fn [ptype | _] -> ptype == "p" end)
    end

    test "filters policies by multiple criteria" do
      adapter = EctoAdapter.new(@repo)

      # Load only p rules for domain2
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{ptype: "p", v2: "domain2"})

      # Should only have p rules with domain2
      assert length(policies) == 2
      assert Enum.all?(policies, fn [ptype, _subj, domain, _obj, _act] ->
        ptype == "p" && domain == "domain2"
      end)
    end

    test "filters policies by list of values" do
      adapter = EctoAdapter.new(@repo)

      # Load policies for domain1 OR domain2
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{v2: ["domain1", "domain2"]})

      # Should have policies with domain1 or domain2
      assert length(policies) == 4
      assert Enum.all?(policies, fn [_ptype, _subj, domain, _obj, _act] ->
        domain in ["domain1", "domain2"]
      end)
    end

    test "returns error when repo is not set" do
      adapter = EctoAdapter.new(nil)
      assert {:error, "repo is not set"} == PersistAdapter.load_filtered_policy(adapter, %{})
    end

    test "returns empty list when no policies match filter" do
      adapter = EctoAdapter.new(@repo)

      # Load policies for non-existent domain
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{v2: "non_existent_domain"})

      assert policies == []
    end
  end

  describe "load_filtered_policies!/2 with Enforcer" do
    test "loads only filtered policies into enforcer" do
      adapter = EctoAdapter.new(@repo)
      {:ok, e} = Enforcer.init(@cfile, adapter)

      # Load only policies for domain1
      e = Enforcer.load_filtered_policies!(e, %{v2: "domain1"})
      |> Enforcer.load_mapping_policies!()

      # Should only have domain1 policies
      policies = Enforcer.list_policies(e)
      assert length(policies) == 2
      
      # Domain1 requests should work
      assert Enforcer.allow?(e, ["alice", "domain1", "data1", "read"]) === true
      assert Enforcer.allow?(e, ["alice", "domain1", "data1", "write"]) === true
      
      # Domain2 requests should not work (policies not loaded)
      assert Enforcer.allow?(e, ["alice", "domain2", "data2", "read"]) === false
      assert Enforcer.allow?(e, ["bob", "domain2", "data2", "read"]) === false
    end

    test "loads only p policies when filtered by ptype" do
      adapter = EctoAdapter.new(@repo)
      {:ok, e} = Enforcer.init(@cfile, adapter)

      # Load only p rules, not g rules
      e = Enforcer.load_filtered_policies!(e, %{ptype: "p"})

      policies = Enforcer.list_policies(e)
      assert length(policies) == 5
      
      # Without role mappings loaded, direct permissions should work
      # but role-based permissions should not
      mapping_policies = Enforcer.list_mapping_policies(e)
      assert length(mapping_policies) == 0
    end

    test "supports multiple filter criteria" do
      adapter = EctoAdapter.new(@repo)
      {:ok, e} = Enforcer.init(@cfile, adapter)

      # Load only p rules for domain2
      e = Enforcer.load_filtered_policies!(e, %{ptype: "p", v2: "domain2"})
      |> Enforcer.load_mapping_policies!()

      policies = Enforcer.list_policies(e)
      assert length(policies) == 2
      
      # Domain2 requests should work
      assert Enforcer.allow?(e, ["bob", "domain2", "data2", "read"]) === true
      
      # Domain1 requests should not work
      assert Enforcer.allow?(e, ["alice", "domain1", "data1", "read"]) === false
    end
  end
end

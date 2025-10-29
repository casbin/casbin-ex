defmodule Acx.Enforcer.RbacDomainRoleInheritanceTest do
  use ExUnit.Case, async: true
  alias Acx.Enforcer

  @cfile "../data/rbac_domain.conf" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)
    {:ok, e: e}
  end

  describe "role-to-role inheritance with domains" do
    test "user inherits permissions through role chain within domain", %{e: e} do
      domain = "org:test123"

      # Set up permissions for each role
      e = e |> Enforcer.add_policy!({:p, ["reader", domain, "blog_post", "read"]})
      e = e |> Enforcer.add_policy!({:p, ["author", domain, "blog_post", "modify"]})
      e = e |> Enforcer.add_policy!({:p, ["admin", domain, "blog_post", "delete"]})

      # Set up role inheritance chain: admin → author → reader
      e = e |> Enforcer.add_mapping_policy!({:g, "author", "reader", domain})
      e = e |> Enforcer.add_mapping_policy!({:g, "admin", "author", domain})

      # Assign user to admin role
      e = e |> Enforcer.add_mapping_policy!({:g, "user:alice", "admin", domain})

      # Test permissions - alice should inherit all permissions through the role chain
      assert e |> Enforcer.allow?(["user:alice", domain, "blog_post", "delete"]) === true
      assert e |> Enforcer.allow?(["user:alice", domain, "blog_post", "modify"]) === true
      assert e |> Enforcer.allow?(["user:alice", domain, "blog_post", "read"]) === true
    end

    test "role inheritance is isolated per domain", %{e: e} do
      domain1 = "org:company1"
      domain2 = "org:company2"

      # Set up permissions for reader role in both domains
      e = e |> Enforcer.add_policy!({:p, ["reader", domain1, "data", "read"]})
      e = e |> Enforcer.add_policy!({:p, ["reader", domain2, "data", "read"]})
      e = e |> Enforcer.add_policy!({:p, ["admin", domain1, "data", "write"]})

      # Set up role inheritance only in domain1
      e = e |> Enforcer.add_mapping_policy!({:g, "admin", "reader", domain1})

      # Assign user to admin role in both domains
      e = e |> Enforcer.add_mapping_policy!({:g, "bob", "admin", domain1})
      e = e |> Enforcer.add_mapping_policy!({:g, "bob", "admin", domain2})

      # Bob should inherit reader permissions in domain1 but not in domain2
      assert e |> Enforcer.allow?(["bob", domain1, "data", "read"]) === true
      assert e |> Enforcer.allow?(["bob", domain1, "data", "write"]) === true
      assert e |> Enforcer.allow?(["bob", domain2, "data", "read"]) === false
    end

    test "multi-level role inheritance with domains", %{e: e} do
      domain = "org:deep"

      # Set up a 4-level hierarchy
      e = e |> Enforcer.add_policy!({:p, ["viewer", domain, "doc", "view"]})
      e = e |> Enforcer.add_policy!({:p, ["editor", domain, "doc", "edit"]})
      e = e |> Enforcer.add_policy!({:p, ["moderator", domain, "doc", "approve"]})
      e = e |> Enforcer.add_policy!({:p, ["super_admin", domain, "doc", "delete"]})

      # Create inheritance chain: super_admin → moderator → editor → viewer
      e = e |> Enforcer.add_mapping_policy!({:g, "editor", "viewer", domain})
      e = e |> Enforcer.add_mapping_policy!({:g, "moderator", "editor", domain})
      e = e |> Enforcer.add_mapping_policy!({:g, "super_admin", "moderator", domain})

      # Assign user to top role
      e = e |> Enforcer.add_mapping_policy!({:g, "charlie", "super_admin", domain})

      # Charlie should inherit all permissions through the chain
      assert e |> Enforcer.allow?(["charlie", domain, "doc", "delete"]) === true
      assert e |> Enforcer.allow?(["charlie", domain, "doc", "approve"]) === true
      assert e |> Enforcer.allow?(["charlie", domain, "doc", "edit"]) === true
      assert e |> Enforcer.allow?(["charlie", domain, "doc", "view"]) === true
    end

    test "removing intermediate role in chain breaks inheritance", %{e: e} do
      domain = "org:break"

      # Set up permissions
      e = e |> Enforcer.add_policy!({:p, ["viewer", domain, "resource", "read"]})
      e = e |> Enforcer.add_policy!({:p, ["editor", domain, "resource", "write"]})
      e = e |> Enforcer.add_policy!({:p, ["admin", domain, "resource", "delete"]})

      # Create inheritance chain
      e = e |> Enforcer.add_mapping_policy!({:g, "editor", "viewer", domain})
      e = e |> Enforcer.add_mapping_policy!({:g, "admin", "editor", domain})
      e = e |> Enforcer.add_mapping_policy!({:g, "dave", "admin", domain})

      # Dave should have all permissions
      assert e |> Enforcer.allow?(["dave", domain, "resource", "read"]) === true
      assert e |> Enforcer.allow?(["dave", domain, "resource", "write"]) === true
      assert e |> Enforcer.allow?(["dave", domain, "resource", "delete"]) === true

      # Remove intermediate role inheritance
      e = e |> Enforcer.remove_mapping_policy!({:g, "editor", "viewer", domain})

      # Dave should no longer have viewer permissions
      assert e |> Enforcer.allow?(["dave", domain, "resource", "read"]) === false
      assert e |> Enforcer.allow?(["dave", domain, "resource", "write"]) === true
      assert e |> Enforcer.allow?(["dave", domain, "resource", "delete"]) === true
    end
  end
end

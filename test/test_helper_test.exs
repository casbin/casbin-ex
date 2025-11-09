defmodule Acx.TestHelperTest do
  use ExUnit.Case, async: true

  import Acx.TestHelper

  alias Acx.{EnforcerServer, EnforcerSupervisor}

  @cfile "../data/acl.conf" |> Path.expand(__DIR__)

  describe "unique_enforcer_name/0" do
    test "generates unique names" do
      name1 = unique_enforcer_name()
      name2 = unique_enforcer_name()

      assert is_binary(name1)
      assert is_binary(name2)
      assert name1 != name2
      assert String.starts_with?(name1, "test_enforcer_")
      assert String.starts_with?(name2, "test_enforcer_")
    end
  end

  describe "unique_enforcer_name/1" do
    test "generates unique names with custom prefix" do
      name1 = unique_enforcer_name("my_test")
      name2 = unique_enforcer_name("my_test")

      assert is_binary(name1)
      assert is_binary(name2)
      assert name1 != name2
      assert String.starts_with?(name1, "my_test_")
      assert String.starts_with?(name2, "my_test_")
    end
  end

  describe "cleanup_enforcer/1" do
    test "removes enforcer from registry and ETS" do
      ename = unique_enforcer_name()
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)

      # Verify enforcer exists
      assert :ets.lookup(:enforcers_table, ename) != []
      assert Registry.lookup(Acx.EnforcerRegistry, ename) != []

      # Cleanup
      cleanup_enforcer(ename)

      # Verify cleanup
      assert :ets.lookup(:enforcers_table, ename) == []
      assert Registry.lookup(Acx.EnforcerRegistry, ename) == []
    end

    test "handles non-existent enforcer gracefully" do
      assert :ok = cleanup_enforcer("non_existent_enforcer")
    end
  end

  describe "setup_enforcer/1" do
    test "creates unique enforcer and returns it in context" do
      {:ok, context} = setup_enforcer(@cfile)

      assert Keyword.has_key?(context, :enforcer_name)
      ename = context[:enforcer_name]

      assert is_binary(ename)
      assert Registry.lookup(Acx.EnforcerRegistry, ename) != []

      # Cleanup
      cleanup_enforcer(ename)
    end
  end

  describe "async test isolation" do
    setup do
      setup_enforcer(@cfile)
    end

    test "test 1 can add and query policies independently", %{enforcer_name: ename} do
      :ok = EnforcerServer.add_policy(ename, {:p, ["test1_user", "test1_data", "read"]})
      
      policies = EnforcerServer.list_policies(ename, %{sub: "test1_user"})
      assert length(policies) == 1
      
      assert EnforcerServer.allow?(ename, ["test1_user", "test1_data", "read"])
      refute EnforcerServer.allow?(ename, ["test2_user", "test2_data", "read"])
    end

    test "test 2 can add and query policies independently", %{enforcer_name: ename} do
      :ok = EnforcerServer.add_policy(ename, {:p, ["test2_user", "test2_data", "write"]})
      
      policies = EnforcerServer.list_policies(ename, %{sub: "test2_user"})
      assert length(policies) == 1
      
      assert EnforcerServer.allow?(ename, ["test2_user", "test2_data", "write"])
      refute EnforcerServer.allow?(ename, ["test1_user", "test1_data", "read"])
    end

    test "test 3 starts with clean state", %{enforcer_name: ename} do
      # Should not see policies from test 1 or test 2
      policies = EnforcerServer.list_policies(ename, %{})
      assert policies == []
      
      refute EnforcerServer.allow?(ename, ["test1_user", "test1_data", "read"])
      refute EnforcerServer.allow?(ename, ["test2_user", "test2_data", "write"])
    end
  end
end

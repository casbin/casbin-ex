defmodule HelpersTest do
  use ExUnit.Case
  doctest Acx.Helpers

  alias Acx.Helpers

  describe "get_while/3" do
    test "returns empty list if the input is empty list" do
      assert Helpers.get_while(&is_atom/1, []) == {[], [], 0}
      assert Helpers.get_while(&is_atom/1, [], true) == {[], [], 0}
      assert Helpers.get_while(&is_atom/1, [], false) == {[], [], 0}
    end

    test "returns empty list if none are satifying the condition" do
      list = [1, 2, 3]
      assert Helpers.get_while(&is_atom/1, list) == {[], list, 0}
      assert Helpers.get_while(&is_atom/1, list, true) == {[], list, 0}
      assert Helpers.get_while(&is_atom/1, list, false) == {[], list, 0}
    end

    test "returns one item from the list satisfying condition" do
      list = [:a, 2, "foo"]

      assert Helpers.get_while(&is_atom/1, list) ==
      {[:a], [2, "foo"], 1}

      assert Helpers.get_while(&is_atom/1, list, true) ==
      {[:a], [2, "foo"], 1}

      assert Helpers.get_while(&is_atom/1, list, false) ==
      {[:a], [2, "foo"], 1}
    end

    test "returns two items from the list in reverse order satisfying the
    condition" do
      list = [:a, :b, 1, "foo"]
      assert {[:b, :a], [1, "foo"], 2} == Helpers.get_while(&is_atom/1, list)
      assert {[:b, :a], [1, "foo"], 2} ==
        Helpers.get_while(&is_atom/1, list, true)
    end

    test "returns two items from the list in correct order satisfying the
    condition" do
      assert {[:a, :b], [1, "foo"], 2} ==
        Helpers.get_while(&is_atom/1, [:a, :b, 1, "foo"], false)
    end

    test "returns all items from the list in revers order satisfying
    the condition" do
      list = [:a, :b, :c]
      assert {[:c, :b, :a], [], 3} == Helpers.get_while(&is_atom/1, list)
      assert {[:c, :b, :a], [], 3} ==
        Helpers.get_while(&is_atom/1, list, true)
    end

    test "returns all itesm from the list in correct order satisfying
    the condition" do
      assert {[:a, :b, :c], [], 3} ==
        Helpers.get_while(&is_atom/1, [:a, :b, :c], false)
    end

  end

end

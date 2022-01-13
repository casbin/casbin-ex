defmodule Acx.Model.MatcherTest do
  use ExUnit.Case, async: true
  alias Acx.Model.Matcher
  doctest Acx.Model.Matcher

  describe "nested structs" do
    test "/" do
      m = Acx.Model.Matcher.new("r.sub.key == p.sub.id.key")
      r1 = %{sub: %{key: 1}}
      p1 = %{sub: %{id: %{key: 1}}}
      p2 = %{sub: %{id: %{key: 2}}}
      assert !!Acx.Model.Matcher.eval!(m, %{p: p1, r: r1})
      refute !!Acx.Model.Matcher.eval!(m, %{p: p2, r: r1})
    end
  end
end

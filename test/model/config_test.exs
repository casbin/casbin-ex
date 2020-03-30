defmodule Acx.Model.ConfigTest do
  use ExUnit.Case, async: true
  alias Acx.Model.Config
  doctest Acx.Model.Config

  describe "new/1" do
    test "returns the correct key-value pairs under :undefined_section" do
      assert %Config{sections: sections} =
        "../data/kv.conf"
        |> Path.expand(__DIR__)
        |> Config.new

      assert [{:undefined_section, kvs}] = sections
      assert kvs == [
        r: "sub,obj,act",
        p: "sub,obj,act",
        e: "some(where(p.eft==allow))",
        m: "r.sub==p.sub&&r.obj==p.obj&&r.act==p.act"
      ]
    end

    test "returns correct number of sections for ACL config" do
      assert %Config{sections: sections} =
        "../data/acl.conf"
        |> Path.expand(__DIR__)
        |> Config.new

      assert [
        request_definition: requests,
        policy_definition: policies,
        policy_effect: effects,
        matchers: matchers
      ] = sections

      assert requests == [r: "sub,obj,act"]
      assert policies == [p: "sub,obj,act"]
      assert effects == [e: "some(where(p.eft==allow))"]
      assert matchers == [m: "r.sub==p.sub&&r.obj==p.obj&&r.act==p.act"]
    end

    test "returns correct number of sections for RBAC config" do
      assert %Config{sections: sections} =
        "../data/rbac.conf"
        |> Path.expand(__DIR__)
        |> Config.new

      assert [
        request_definition: requests,
        policy_definition: policies,
        role_definition: roles,
        policy_effect: effects,
        matchers: matchers
      ] = sections

      assert requests == [r: "sub,obj,act"]
      assert policies == [p: "sub,obj,act"]
      assert roles == [g: "_,_"]
      assert effects == [e: "some(where(p.eft==allow))"]
      assert matchers == [m: "g(r.sub,p.sub)&&r.obj==p.obj&&r.act==p.act"]
    end

    test "returns correct number of sections for RBAC with resource roles" do
      assert %Config{sections: sections} =
        "../data/rbac_with_resource_roles.conf"
        |> Path.expand(__DIR__)
        |> Config.new

      assert [
        request_definition: requests,
        policy_definition: policies,
        role_definition: roles,
        policy_effect: effects,
        matchers: matchers
      ] = sections


      assert requests == [r: "sub,obj,act"]
      assert policies == [p: "sub,obj,act"]
      assert roles == [
        g: "_,_",
        g2: "_,_"
      ]
      assert effects == [e: "some(where(p.eft==allow))"]
      assert matchers == [
        m: "g(r.sub,p.sub)&&g2(r.obj,p.obj)&&r.act==p.act"
      ]
    end

  end
end

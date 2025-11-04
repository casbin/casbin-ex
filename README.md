# Casbin-Ex

[![GitHub Actions](https://github.com/casbin/casbin-ex/actions/workflows/ci.yml/badge.svg)](https://github.com/casbin/casbin-ex/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/acx.svg)](https://hex.pm/packages/acx)
[![Release](https://img.shields.io/github/release/casbin/casbin-ex.svg)](https://github.com/casbin/casbin-ex/releases/latest)
[![Discord](https://img.shields.io/discord/1022748306096537660?logo=discord&label=discord&color=5865F2)](https://discord.gg/S5UjpzGZjN)

**News**: still worry about how to write the correct Casbin policy? ``Casbin online editor`` is coming to help! Try it at: https://casbin.org/editor/

Casbin-Ex is a powerful and efficient open-source access control library for Elixir projects. It provides support for enforcing authorization based on various [access control models](https://en.wikipedia.org/wiki/Computer_security_model).

## All the languages supported by Casbin:

| [![golang](https://casbin.org/img/langs/golang.png)](https://github.com/casbin/casbin) | [![java](https://casbin.org/img/langs/java.png)](https://github.com/casbin/jcasbin) | [![nodejs](https://casbin.org/img/langs/nodejs.png)](https://github.com/casbin/node-casbin) | [![php](https://casbin.org/img/langs/php.png)](https://github.com/php-casbin/php-casbin) |
|----------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| [Casbin](https://github.com/casbin/casbin)                                             | [jCasbin](https://github.com/casbin/jcasbin)                                        | [node-Casbin](https://github.com/casbin/node-casbin)                                        | [PHP-Casbin](https://github.com/php-casbin/php-casbin)                                   |
| production-ready                                                                       | production-ready                                                                    | production-ready                                                                            | production-ready                                                                         |

| [![python](https://casbin.org/img/langs/python.png)](https://github.com/casbin/pycasbin) | [![dotnet](https://casbin.org/img/langs/dotnet.png)](https://github.com/casbin-net/Casbin.NET) | [![c++](https://casbin.org/img/langs/cpp.png)](https://github.com/casbin/casbin-cpp) | [![rust](https://casbin.org/img/langs/rust.png)](https://github.com/casbin/casbin-rs) |
|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| [PyCasbin](https://github.com/casbin/pycasbin)                                           | [Casbin.NET](https://github.com/casbin-net/Casbin.NET)                                         | [Casbin-CPP](https://github.com/casbin/casbin-cpp)                                   | [Casbin-RS](https://github.com/casbin/casbin-rs)                                      |
| production-ready                                                                         | production-ready                                                                               | production-ready                                                                     | production-ready                                                                      |

## Documentation

https://casbin.org/docs/overview

## Installation

```elixir
def deps do
  [
    {:acx, git: "https://github.com/casbin/casbin-ex"}
  ]
end
```

## [Access Control List (ACL)](https://en.wikipedia.org/wiki/Access-control_list)

Let's say we have just built a wonderful blogging system, and now we want
to add the access control feature to it to control **who can do what** with
the resource named `blog_post`. Our system requirements would look something
like this:

|       | blog_post.create | blog_post.read | blog_post.modify | blog_post.delete |
| ----- |:----------------:|:--------------:|:----------------:|:----------------:|
| alice |     yes          |       yes      |        yes       |          yes     |
| bob   |     no           |       yes      |        no        |          yes     |
| peter |     yes          |       yes      |        yes       |          no      |

Based on these requirements, our first step is to choose an appropriate
access control model. Let's say we choose to go with the ACL model.
In Casbin-Ex, an access control model is abstracted into a
config file based on the **[PERM Meta-Model](https://casbin.org/docs/how-it-works)**. The content of the config file for our system would look
like this:

```ini
# blog_ac.conf

# We want each request to be a tuple of three items, in which first item
# associated with the attribute named `sub`, second `obj` and third `act`.
# An example of a valid request based on this definition is
# `["alice, "blog_post", "read"]` (can `alice` `read` `blog_post`?).
[request_definition]
r = sub, obj, act

# Each policy definition should have a key and a list of attributes separated by
# an equal `=` sign. In Casbin-Ex all policy rules have in common the `eft` attribute
# and it can only take value of either `"allow"` or `"deny"`, so you can omit
# it in your policy definition.
[policy_definition]
p = sub, obj, act

# Policy effect defines whether the access should be approved or denied
# if multiple policy rules match the request.
# We use the following policy effect for our blog system to mean that:
# if there's any matched policy rule of type `allow` (i.e `eft` == "allow"),
# the final effect is `allow`. Which also means if there's no match or all
# matches are of type `deny`, the final effect is `deny`.
[policy_effect]
e = some(where (p.eft == allow))

# matchers is just a boolean expression used to determine whether a request
# matches the given policy rule.
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

```

Done with the model. Our next step is to define policy rules based on the
system requirements and the policy definition. We can choose to put these
rules in a database or in our case a `*.csv` file named `blog_ac.csv`:

```
p, alice, blog_post, create
p, alice, blog_post, read
p, alice, blog_post, modify
p, alice, blog_post, delete

p, bob, blog_post, read

p, peter, blog_post, create
p, peter, blog_post, read
p, peter, blog_post, modify

```

Note that, first of all, since we don't specify the value for the `eft`
attribute for any of the above rules, all of our rules are of type `allow`
(i.e., `yes`) by default. Second, we don't have to define any `deny`
(i.e., `no`) rules for our system.

The final step is to combine the model, the policy rules and Casbin-Ex to
construct our access control system.

```elixir
alias Acx.{EnforcerSupervisor, EnforcerServer}

# Give our system a name so that we can reference it by its name
# rather than the process ID (a.k.a `pid`).
ename = "blog_ac"

# Starts a new enforcer process and supervises it.
EnforcerSupervisor.start_enforcer(ename, blog_ac.conf)

# Load policy rules.
EnforcerServer.load_policies(ename, blog_ac.csv)

new_req = ["alice", "blog_post", "read"]

case EnforcerServer.allow?(ename, new_req) do
  true ->
    # Yes, this `new_req` is allowed

  false ->
    # Nope, `new_req` is denied (not allowed)
end
```

If you are not a fan of supervision tree or stateful server, read on to
figure out how to use Casbin-Ex without any of those.

## [Role-Based Access Control (RBAC)](https://en.wikipedia.org/wiki/Role-based_access_control)

Our ACL access control system is working just fine for the initial purpose, but
now our business is expanding rapidly, so we need a more flexible access
control model to meet new business requirements. We went back to the
drawing board and came up with this design for our new system:

![rbac diagram](rbac.png)

We assign different roles to different users: `bob` has the role `reader`,
`peter` has the role `author`, and `alice` has the role `admin`, and so on.
We then define mappings from `role` to `permission` (instead of asking
*who can do what* like in the ACL model, now we ask **which role can
do what?**). We also define mappings from role to role to represent
inheritance. In the above diagram, `admin` inherits from `author`,
which in turn inherits from `reader`.

Note that the *has role* or *inherits from* relation is [transitive](https://en.wikipedia.org/wiki/Transitive_relation).

Based on this design, the config file for our new model would look like
this:

```ini
# blog_ac.conf

[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

# This is the name of the mapping we mentioned above. We call it `g`
# to make it compatible with Casbin (which only allows names
# like `g, g2, ...`), but you can name it however you prefer as long as
# you're consistent.
[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

# We change this part `r.sub == p.sub` of our initial matcher expression to
# `g(r.sub, p.sub)` to mean that: if `r.sub` has role (or inherits from)
# `p.sub` and ... and ...
[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act

```

And the content of the file `blog_ac.csv` now become:

```
p, reader, blog_post, read
p, author, blog_post, modify
p, author, blog_post, create
p, admin, blog_post, delete

g, bob, reader
g, peter, author
g, alice, admin

g, author, reader
g, admin, author
```

Finally:

```elixir
alias Acx.{EnforcerSupervisor, EnforcerServer}

ename = "blog_ac"
EnforcerSupervisor.start_enforcer(ename, blog_ac.conf)
EnforcerServer.load_policies(ename, blog_ac.csv)

# You only have to add this new line to load mapping rules. Unlike other Casbin
# implementations, Casbin-Ex distinguishes between `normal` policy rules and `mapping` rules.
# We've just happened to put the two types of rules in the same `*.csv` file.
EnforcerServer.load_mapping_policies(ename, blog_ac.csv)

new_req = ["alice", "blog_post", "read"]

case EnforcerServer.allow?(ename, new_req) do
  true ->
    # Yes, this `new_req` is allowed

  false ->
    # Nope, `new_req` is denied (not allowed)
end
```

As you can see, the cost of switching or upgrading to another access control
mechanism is as simple as modifying the configuration.

## RESTful Example

The config file:

```ini
# restful_ac.conf

[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[policy_effect]
e = some(where (p.eft == allow))

# The function named `match?` will be defined later in code.
[matchers]
m = r.sub == p.sub && match?(r.obj, p.obj) && match?(r.act, p.act)
```

Policy rules `restful_ac.csv`:

```
p, alice, /alice_data/.*, GET
p, alice, /alice_data/resource1, POST

p, bob, /alice_data/resource2, GET
p, bob, /bob_data/.*, POST

p, peter, /peter_data, (GET)|(POST)
```

Code:

```elixir
alias Acx.{EnforcerSupervisor, EnforcerServer}

ename = "restful_ac"
EnforcerSupervisor.start_enforcer(ename, restful_ac.conf)
EnforcerServer.load_policies(ename, restful_ac.csv)

# We have to define the `match?/2` function and add it to our enforcer system.

# This anonymous function is identical to the built-in function
# `regex_match?/2`, but we redefine it here to illustrate the idea of
# how you can customize the system to meet your needs.
fun = fn str, pattern ->
  case Regex.compile("^#{pattern}$") do
    {:error, _} ->
      false

    {:ok, r} ->
      Regex.match?(r, str)
  end
end

# Add `fun` to our system. Note that the name `:match?` is an atom, not
# a string.
EnforcerServer.add_fun(ename, {:match?, fun})

new_req = ["alice", "/alice_data/foo", "GET"]

case EnforcerServer.allow?(ename, new_req) do
  true ->
    # Yes, this `new_req` is allowed

  false ->
    # Nope, `new_req` is denied (not allowed)
end
```

## Testing

When writing tests with `async: true`, each test needs its own isolated enforcer instance to avoid race conditions. See the [Async Testing Guide](guides/async_testing.md) for detailed instructions on how to write async-safe tests.

Quick example:

```elixir
defmodule MyApp.PolicyTest do
  use ExUnit.Case, async: true
  import Acx.TestHelper
  
  setup do
    setup_enforcer("path/to/config.conf")
  end
  
  test "some test", %{enforcer_name: ename} do
    Acx.EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
    assert Acx.EnforcerServer.allow?(ename, ["alice", "data", "read"])
  end
end
```

## Supported Models

Casbin-Ex supports the following access control models:

1. [**ACL (Access Control List)**](https://en.wikipedia.org/wiki/Access-control_list)
2. **ACL with [superuser](https://en.wikipedia.org/wiki/Superuser)**
3. **ACL without users**: especially useful for systems that don't have authentication or user log-ins
4. **ACL without resources**: some scenarios may target a type of resources instead of an individual resource
5. **[RBAC (Role-Based Access Control)](https://en.wikipedia.org/wiki/Role-based_access_control)**
6. **RBAC with resource roles**: both users and resources can have roles (or groups) at the same time
7. **RBAC with domains/tenants**: users can have different role sets for different domains/tenants
8. **[ABAC (Attribute-Based Access Control)](https://en.wikipedia.org/wiki/Attribute-Based_Access_Control)**: syntax sugar like `resource.Owner` can be used to get the attribute for a resource
9. **[RESTful](https://en.wikipedia.org/wiki/Representational_state_transfer)**: supports paths like `/res/*`, `/res/:id` and HTTP methods like `GET`, `POST`, `PUT`, `DELETE`
10. **Deny-override**: both allow and deny authorizations are supported, deny overrides the allow
11. **Priority**: the policy rules can be prioritized like firewall rules

## TODO

### Matchers Functions

Implement all [matchers' functions](https://casbin.org/docs/function):
- [x] regexMatch
- [ ] keyMatch
- [ ] keyGet
- [x] keyMatch2
- [ ] keyGet2
- [ ] keyMatch3
- [ ] keyMatch4
- [ ] ipMatch
- [ ] globMatch

## License

This project is licensed under the [Apache 2.0 license](LICENSE).

## Getting Help

- Casbin-Ex documentation: https://casbin.org/docs/overview
- Casbin website: https://casbin.org
- Discord: https://discord.gg/S5UjpzGZjN
- GitHub Issues: https://github.com/casbin/casbin-ex/issues

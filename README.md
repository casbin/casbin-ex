# Acx
Acx is an access control library that can do whatever shit
[Casbin](https://casbin.org/) can and much more...

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

Based on this requirements, our first step is to choose an appropriate
access control model. Let's say we choose to go with the ACL model.
Similar to Casbin, in Acx, an access control model is abstracted into a
config file based on the **[PERM Meta-Model](https://casbin.org/docs/how-it-works)**. The content of the config file for our system would look
like so:

```ini
# blog_ac.conf

# We want each request to be a tuple of three items, in which first item
# associated with the attribute named `sub`, second `obj` and third `act`.
# An example of a valid request based on this definition is
# `["alice, "blog_post", "read"]` (can `alice` `read` `blog_post`?).
[request_definition]
r = sub, obj, act

# Each policy definition should have a key and a list of attributes separated by
# an equal `=` sign. In Acx all policy rules have in common the `eft` attribute
# and it can only take value of either `"allow"` or `"deny"`, so you can ommit
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

Note that, first of all , since we don't specify the value for the `eft`
attribute for any of the above rules, all of our rules are of type `allow`
(a.k.a `yes`) by default. Second, we don't have to define any `deny`
(a.k.a `no`) rules for our system.

The final step is to combine the model, the policy rules and Acx to
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
figure our how to use Acx without any of those.

## [Role Base Access Control (RBAC)](https://en.wikipedia.org/wiki/Role-based_access_control)

Our ACL access control system is working just fine for initial purpose, but
now our bussiness is expanding like nuts, so we need a more flexible access
control model to meet new bussiness requirements. We went back to the
drawing-board and came up with this design for our new system:

![rbac diagram](rbac.png)

We assign different roles to different users, `bob` has the role `reader`,
`peter` has the role `author` and `alice` has the role `admin`, and so on...
We then define mappings from `role` to `permission` (instead of asking
*who can do what* like in the ACL model, now it's time to ask **which role can
do what?**). We also define mappings from role to role  to represent
inheritance. In the above diagram, we have `admin` inherits from `author`,
which in turn inherits from `reader`.

Note that *has role* or *inherits from* relation is [transitive](https://en.wikipedia.org/wiki/Transitive_relation).

Based on this design, the config file for our new model would look like
so:

```ini
# blog_ac.conf

[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

# This is the name of the mapping we mentioned above, I call it `g`
# to make it compatible with Casbin (which for some reason only allows name
# like `g, g2, ...`) but you can name it whatever shit you like so long as
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

# You only have to add this new line to load mapping rules. Unlike Casbin
# Acx distinguishes from `normal` policy rules and `mapping` rules.
# We've just happended to put the two types of rules in the same `*.csv` file.
EnforcerServer.load_mapping_policies(ename, blog_ac.csv)

new_req = ["alice", "blog_post", "read"]

case EnforcerServer.allow?(ename, new_req) do
  true ->
    # Yes, this `new_req` is allowed

  false ->
    # Nope, `new_req` is denied (not allowed)
end
```

As you can see, the cost of swithching or upgrading to another access control
mechanism is just as cheap as modifying the configuration.

## RESTful example
TODO

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

# We have to define the `match?/2` and add it to our enforcer system.

# This anonymous function is idential to the built-in function
# `regex_match?/2`, but I redifine it here to illustrate the idea of
# how you can customize the system to meet your need.
fun = fn str, pattern ->
  case Regex.compile("^#{pattern}$") do
    {:error, _} ->
      false

    {:ok, r} ->
      Regex.match?(r, str)
  end
end

# add `fun` to our system. Note that the name `:match?` is an atom not
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

## TODO

### Global

Implement all [matchers' functions](https://casbin.org/docs/function):
- [x] regexMatch
- [ ] keyMatch
- [ ] keyGet
- [x] KeyMatch2
- [ ] keyGet2
- [ ] keyMatch3
- [ ] keyMatch4
- [ ] ipMatch
- [ ] globMatch

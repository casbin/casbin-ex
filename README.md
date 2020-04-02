# Acx
Acx is a access control library that can do whatever shit [Casbin](https://casbin.org/) can and much more...

## Installation

```elixir
def deps do
  [
    {:acx, git: "https://github.com/ngoclinhng/acx.git"}
  ]
end
```

## [Access Control List (ACL)](https://en.wikipedia.org/wiki/Access-control_list)

Let's say you have just built a blogging system, and now you want to add the
access control feature to it to control who can do what with the resource `blog_post`. Our system requirements would look something like this:

|       | blog_post.create | blog_post.read | blog_post.update | blog_post.delete |
| ----- |:----------------:|:--------------:|:----------------:|:----------------:|
| alice |     yes          |       yes      |        yes       |          yes     |
| bob   |     no           |       yes      |        no        |          yes     |
| peter |     yes          |       yes      |        yes       |          no      |

Based on this requirements, your first step is to choose an appropriate access control model. Let's say we choose to go with the ACL model. Similar to Casbin, in Acx, an access control model is abstracted into a config file based on the **[PERM Meta-Model](https://vicarie.in/posts/generalized-authz.html)**. The content of the config file for our system would look like so:

```ini
# blog.conf

# We want each request to be a tuple of three items, in which first item associated with the
# attribute named `sub`, second `obj` and third `act`. An example of a valid request is
# `["alice, "blog_post", "read"]` (can `alice` `read` `blog_post`?).
[request_definition]
r = sub, obj, act

# Each request definition should have a key and a list of attributes separated by an equal `=` sign.
# In Acx all policy rule have in common the `eft` attribute and it can only take value of either
# `"allow"` or `"deny"`, so you can ommit it in your policy definition. If you're familiar with
# object-oriented-programming, you could think of policy definition as a class and each policy rule
# is an instance of such class.
#
# Examples of valid policy rules (along with and how Acx interprets them) based on this definition
# and our system requirements above are:
#
#   p, alice, blog_post, read  -> [sub: "alice", obj: "blog_post", act: "read", eft: "allow"]
#   p, alice, blog_post, create, allow -> [sub: "alice", obj: "blog_post", act: "create", eft: "allow"]
#   p, bob, blog_post, create, deny -> [sub: "bob", obj: "blog_post", act: "create", eft: "deny"]
[policy_definition]
p = sub, obj, act

# Policy effect
[policy_effect]
e = some(where (p.eft == allow))

# Matchers
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

```

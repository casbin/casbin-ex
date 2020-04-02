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

# Each policy definition should have a key and a list of attributes separated by an equal `=` sign.
# In Acx all policy rules have in common the `eft` attribute and it can only take value of either
# `"allow"` or `"deny"`, so you can ommit it in your policy definition.
#
# Examples of valid policy rules (along with their meanings) based on this definition and our system
# requirements above are:
#
#           policy rule               |                  meaning
#                                     |
#  p, alice, blog_post, read          | allow `alice` to `read` `blog_post` (`eft` implicitly "allow")
#  p, alice, blog_post, create, allow | allow `alice` to `create` `blog_post` (`eft` explicitly "allow")
#  p, bob, blog_post, create, deny    | deny `bob` to `create` `blog_post` (`eft` explicitly "deny")
[policy_definition]
p = sub, obj, act

# Policy effect defines whether the access should be approved or denied
# if multiple policy rules match the request.
#
# For now, only the following policy effect rules are valid:
#
#  1. `"some(where(p.eft==allow))"`: if there's any matched policy rule of
#    type `allow`, the final effect is `allow`. Which means if there's no
#    match or all matches are of type `deny`, the final effect is `deny`.
#
#  2. `"!some(where(p.eft==deny))"`: if there's no matched policy rules of
#    type `deny`, the final effect is `allow`.
[policy_effect]
e = some(where (p.eft == allow))

# matchers is just a boolean expression used to determine whether a request
# matches the given policy rule.
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

```

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
| alice |     yes                 yes              yes                 yes
| bob   |     no                  yes              no                  yes
| peter |     yes                 yes              yes                 no

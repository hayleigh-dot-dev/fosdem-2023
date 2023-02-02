```
./scripts/run.sh
```

The run script will build both the front and backend, copy things into the right
places, and then run the erlang server.

## `server/`

Everything under `server/` is code related to the _backend_ of the project. The
backend is an erlang app, so it's important to wrap gleam modules in `if erlang { ... }`
so we don't mess up frontend builds.

## `app/`

Everything in here is code related to the _frontend_ of the project. For gleam
source, it's important to wrap the entire module in `if javascript { ... }` so
things build correctly.

## `shared/`

This is where we put code that is shared between the front and backend. We shouldn't
require any FFI here, and we should make sure any dependencies we pull in are
compatible with both erlang and javascript.

## How do I add dependencies?

For javascript dependencies everything is normal, just do `npm i` or `npm i -D`
and you're good to go. For gleam dependencies things are bit more involved because
we really have two gleam apps under one roof here.

The easiest way to add a new dependency is to copy either `gleam.backend.toml`
or `gleam.frontend.toml` into `gleam.toml` (depending on whether you're adding
a front or backend dependency) and then use `gleam add ...` like normal. _Then_
copy the new entry in `gleam.toml` back to either `gleam.backend.toml` or
`gleam.frontend.toml` respectively.

This is a bit of a hassle, I know, but I wanted all the source to live in a
single app and this is the price we must pay for it.

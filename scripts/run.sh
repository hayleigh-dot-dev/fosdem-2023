#!/usr/bin/env bash

# gleam.frontend.toml contains all our gleam dependencies for
# the javascript target.
cp gleam.frontend.toml gleam.toml

# First build the frontend js from our gleam source.
gleam build
# Then bundle that up nicely with vite, do tailwind things, etc...
npx vite build --out-dir ./build/app

# gleam.backend.toml contains all our gleam dependencies for
# the erlang target.
cp gleam.backend.toml gleam.toml

# Actually run the thing!
gleam run
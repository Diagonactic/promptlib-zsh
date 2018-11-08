#!/usr/bin/env zsh

[[ -n "${MODULES}" ]] || declare -ga MODULES=(
  background_job
  crystal
  disk
  elixir
  git
  go
  java
  mercurial
  node
  php
  python
  ruby
  ssh
  subversion
  time
)


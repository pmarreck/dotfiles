#!/usr/bin/env bash

# Bash imports exported functions before resolving PATH. Route every child
# shell—including Codex/Claude tool shells with bundled binaries prepended—to
# the durable ~/bin multicall search safety wrapper.
rg() {
	"$HOME/bin/rg" "$@"
}

find() {
	"$HOME/bin/find" "$@"
}

fd() {
	"$HOME/bin/fd" "$@"
}

export -f rg find fd

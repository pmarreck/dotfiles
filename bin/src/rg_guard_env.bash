#!/usr/bin/env bash

# Bash imports exported functions before resolving PATH. Route every child
# shell—including Codex/Claude tool shells with bundled binaries prepended—to
# the durable ~/bin multicall search safety wrapper. The path is resolved when
# this file is sourced, not at call time, so the functions keep working in
# children that run with a private, empty HOME (as isolated tests do).
for _guard_tool in rg find fd bfs; do
	eval "$_guard_tool() { $(printf %q "$HOME/bin/$_guard_tool") \"\$@\"; }"
done
unset _guard_tool
export -f rg find fd bfs

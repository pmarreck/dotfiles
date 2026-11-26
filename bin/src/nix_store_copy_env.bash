#!/usr/bin/env bash
# Keep agent Bash subprocesses on the same copy policy when PATH is prepended.
# Resolve the guard path now, not at call time: tests often run children with
# a private, empty HOME, where "$HOME/bin/cp" would not exist.
for _guard_tool in cp install rsync; do
	eval "$_guard_tool() { $(printf %q "$HOME/bin/$_guard_tool") \"\$@\"; }"
done
unset _guard_tool
export -f cp install rsync

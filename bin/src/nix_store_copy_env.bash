#!/usr/bin/env bash
# Keep agent Bash subprocesses on the same copy policy when PATH is prepended.
cp() { "$HOME/bin/cp" "$@"; }
install() { "$HOME/bin/install" "$@"; }
rsync() { "$HOME/bin/rsync" "$@"; }
export -f cp install rsync

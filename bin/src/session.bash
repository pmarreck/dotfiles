#!/usr/bin/env bash

# tmux new-or-rejoin session wrapper
session() {
	tmux new -A -s "${1:-default}"
}

if ${INTERACTIVE_SHELL:-false}; then
	if [[ -n ${TMUX:-} ]] && [[ -z ${TMUX_QUICKREF_SHOWN:-} ]]; then
		if command -v tmux-quickref >/dev/null 2>&1; then
			tmux-quickref
			TMUX_QUICKREF_SHOWN=1
		else
			echo "tmux-quickref command not found; skipping quick reference." >&2
		fi
	fi
fi

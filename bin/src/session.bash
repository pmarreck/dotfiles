#!/usr/bin/env bash

# tmux new-or-rejoin session wrapper.
# Works both outside tmux (attach or create-and-attach) and INSIDE tmux, where
# you can't `attach` a nested session — you must `switch-client` instead (the
# old `tmux new -A` silently failed to switch when already inside tmux).
# The `=name` target forces an EXACT match (no accidental prefix-matching).
session() {
	local name="${1:-default}"
	if [ -n "${TMUX:-}" ]; then
		tmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name"
		tmux switch-client -t "=$name"
	else
		# `-D` (uppercase) modifies `-A`'s attach behavior: attach, and detach an
		# older client already viewing this session, preventing mixed-size duplicate
		# redraw storms. Lowercase `-d` means "do NOT attach to the current
		# terminal" — it was here until 2026-07-27 and caused `session NAME` to
		# create the session without joining it, so you had to run it twice.
		tmux new-session -AD -s "$name"
	fi
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

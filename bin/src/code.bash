#!/usr/bin/env bash

# code — jump to a project under $CODE (~/Code) by partial, case-insensitive name.
#
#   code zed          cd into the first ~/Code dir matching *zed* (case-insensitive)
#   code zed --edit   open that dir in your editor instead (via `edit`, which picks
#                     $VISUAL on an interactive terminal else $EDITOR)
#
# Resolution is `glob -i "$CODE/*<query>*/" | head -1`: the trailing slash keeps it
# to DIRECTORIES, -i is case-insensitive, and glob's code-point ordering makes the
# first match deterministic — so a sufficiently specific partial lands you exactly
# where you meant. Must be a sourced function (a PATH executable can't cd the shell).
# Depends on the `glob` script.

code() {
	[ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return

	local query="" do_edit=false base="${CODE:-$HOME/Code}"
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)
				printf '%s\n' \
					"Usage: code <partial-name> [--edit]" \
					"  cd into the first \$CODE (~/Code) directory matching *<partial-name>*" \
					"  (case-insensitive, directories only, code-point-first)." \
					"  --edit / -e   open that directory in your editor instead of cd-ing." >&2
				return 0
				;;
			-e|--edit) do_edit=true; shift ;;
			--)        shift; [ $# -gt 0 ] && { query="$1"; shift; } ;;
			*)         query="$1"; shift ;;
		esac
	done

	if [ -z "$query" ]; then
		echo "code: usage: code <partial-name> [--edit]" >&2
		return 2
	fi

	local target
	target=$(glob -i "$base/*${query}*/" 2>/dev/null | head -1)
	target="${target%/}"

	if [ -z "$target" ] || [ ! -d "$target" ]; then
		echo "code: no directory under $base matches '$query'" >&2
		return 1
	fi

	if $do_edit; then
		edit "$target"
	else
		cd "$target" || return 1
	fi
}

#!/usr/bin/env bash

# code — jump to a project under $CODE (~/Code) by partial, case-insensitive name.
#
#   code zed          cd into the first ~/Code dir matching *zed* (case-insensitive)
#   code zed --edit   open that dir in your editor instead (via `edit`, which picks
#                     $VISUAL on an interactive terminal else $EDITOR)
#
# Resolve direct child directories in byte order with a literal,
# case-insensitive query. Must be sourced to change the caller's directory.

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
	target=$(
		set +f
		shopt -s nullglob nocaseglob
		LC_ALL=C
		for candidate in "$base"/*"$query"*/; do
			[[ -d "$candidate" ]] || continue
			printf '%s\n' "${candidate%/}"
			break
		done
	)

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

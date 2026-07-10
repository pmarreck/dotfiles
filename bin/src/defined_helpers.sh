#!/usr/bin/env sh

in_bash() {
	[ -n "${BASH_VERSION+set}" ]
}

var_defined() {
	in_bash && [ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	case "${1:-}" in
		'' | [!a-zA-Z_]* | *[!a-zA-Z0-9_]*) return 2 ;;
	esac
	if in_bash; then
		declare -p "$1" >/dev/null 2>&1
	else
		eval '[ "${'"$1"'+x}" ]'
	fi
}

func_defined() {
	in_bash && [ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	type "$1" 2>/dev/null | {
		IFS= read -r line || exit 1
		case "$line" in
			*function*) exit 0 ;;
			*)          exit 1 ;;
		esac
	}
}

alias_defined() {
	in_bash && [ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	alias "$1" >/dev/null 2>&1
}

defined() {
	in_bash && [ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	if [ "$#" -eq 0 ]; then
		printf '%s\n' \
			"Usage: defined <name> [name ...]" \
			"Returns 0 if every name is a command, function, alias, variable, builtin, or executable on PATH."
		return 2
	fi
	for word; do
		if alias_defined "$word"; then
			continue
		fi
		if command -v -- "$word" >/dev/null 2>&1; then
			continue
		fi
		if var_defined "$word"; then
			continue
		fi
		return 1
	done
	return 0
}

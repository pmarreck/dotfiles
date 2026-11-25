#!/usr/bin/env bash

agy() {
	local agy_path
	if ! agy_path=$(type -P agy); then
		printf 'agy not found\n' >&2
		return 127
	fi

	# Native management commands and information flags take their original arguments.
	case "${1:-}" in
		[!-]*|-h|--help|-V|--version) "$agy_path" "$@"; return ;;
	esac

	local resume=true add_permissions=true
	local -a args=() defaults=()
	while (( $# > 0 )); do
		case "$1" in
			--noresume)
				resume=false
				shift
				continue ;;
			--)
				args+=("$@")
				break ;;
			-c|--continue|-c=*|--continue=*|-r|--conversation|--resume|-r=*|--conversation=*|--resume=*|--new-project)
				resume=false ;;
			--dangerously-skip-permissions|--dangerously-skip-permissions=*)
				add_permissions=false ;;
			-p|-i|--print|--prompt|--prompt-interactive)
				# The next token is prompt text, even if it spells a wrapper option.
				if (( $# > 1 )); then
					args+=("$1" "$2")
					shift 2
					continue
				fi ;;
		esac
		args+=("$1")
		shift
	done

	"$add_permissions" && defaults+=(--dangerously-skip-permissions)
	"$resume" && defaults+=(--continue)
	"$agy_path" "${defaults[@]}" "${args[@]}"
}

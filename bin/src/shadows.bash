#!/usr/bin/env bash

shadows() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return

	local about usage script_dir test_file self_path
	about="Report aliases and functions that shadow builtins or PATH executables"
	usage="Usage: shadows [-h|--help] [-a|--about] [--test]"
	script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	test_file="$script_dir/../test/shadows_test"
	self_path="$(cd "$script_dir/.." && pwd)/shadows"

	case "$1" in
		-h|--help)
			echo "$usage"
			echo "Print aliases/functions that take precedence over builtins or PATH commands."
			return 0
			;;
		-a|--about)
			echo "$about"
			return 0
			;;
		--test)
			"$test_file" >/dev/null
			return $?
			;;
	esac

	local -a alias_names function_names results

	while IFS= read -r line; do
		local name="${line#alias }"
		name="${name%%=*}"
		alias_names+=("$name")
	done < <(alias -p)

	mapfile -t function_names < <(compgen -A function)

	local format_targets
	format_targets() {
		local deduped=()
		local item
		for item in "$@"; do
			[[ -z "$item" ]] && continue
			local found=false
			local existing
			for existing in "${deduped[@]}"; do
				if [[ "$existing" == "$item" ]]; then
					found=true
					break
				fi
			done
			$found || deduped+=("$item")
		done
		IFS=', '
		echo "${deduped[*]}"
	}

	local collect_alias_shadows
	collect_alias_shadows() {
		local name="$1"
		local -a entries shadows
		mapfile -t entries < <(type -a "$name" 2>/dev/null)
		local has_alias=true
		local line path
		for line in "${entries[@]}"; do
			if [[ "$line" == "$name is an alias for"* || "$line" == "$name is aliased to"* ]]; then
				continue
			fi
			if [[ "$line" == "$name is a function"* ]]; then
				shadows+=("function")
				continue
			fi
			if [[ "$line" == "$name is a shell builtin"* ]]; then
				shadows+=("builtin")
				continue
			fi
			if [[ "$line" == "$name is hashed ("* ]]; then
				path="${line#* (}"
				path="${path%)*}"
				[[ "$path" == "$self_path" ]] && continue
				shadows+=("$path")
				continue
			fi
			if [[ "$line" == "$name is "* ]]; then
				path="${line#"$name is "}"
				[[ "$path" == "$self_path" ]] && continue
				shadows+=("$path")
			fi
		done
		local path_file
		path_file=$(type -P "$name" 2>/dev/null) || path_file=""
		[[ -n "$path_file" && "$path_file" != "$self_path" ]] && shadows+=("$path_file")
		if $has_alias && ((${#shadows[@]} > 0)); then
			results+=("alias $name shadows: $(format_targets "${shadows[@]}")")
		fi
	}

	local collect_function_shadows
	collect_function_shadows() {
		local name="$1"
		local -a entries shadows
		mapfile -t entries < <(type -a "$name" 2>/dev/null)
		local has_function=true
		local line path
		for line in "${entries[@]}"; do
			if [[ "$line" == "$name is a function"* ]]; then
				continue
			fi
			if [[ "$line" == "$name is a shell builtin"* ]]; then
				shadows+=("builtin")
				continue
			fi
			if [[ "$line" == "$name is hashed ("* ]]; then
				path="${line#* (}"
				path="${path%)*}"
				[[ "$path" == "$self_path" ]] && continue
				shadows+=("$path")
				continue
			fi
			if [[ "$line" == "$name is "* ]]; then
				path="${line#"$name is "}"
				[[ "$path" == "$self_path" ]] && continue
				shadows+=("$path")
			fi
		done
		local path_file
		path_file=$(type -P "$name" 2>/dev/null) || path_file=""
		[[ -n "$path_file" && "$path_file" != "$self_path" ]] && shadows+=("$path_file")
		if $has_function && ((${#shadows[@]} > 0)); then
			results+=("function $name shadows: $(format_targets "${shadows[@]}")")
		fi
	}

	local name
	for name in "${alias_names[@]}"; do
		collect_alias_shadows "$name"
	done

	for name in "${function_names[@]}"; do
		[[ "$name" == "shadows" ]] && continue
		collect_function_shadows "$name"
	done

	local count=${#results[@]}
	if ((count > 0)); then
		printf "%s\n" "${results[@]}" | sort
	fi

	if ((count > 255)); then
		printf "Warning: %d shadows detected; exit status capped at 255\n" "$count" >&2
		return 255
	fi

	return "$count"
}

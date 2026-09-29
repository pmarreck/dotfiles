#!/usr/bin/env bash

# Report shell and PATH precedence conflicts with one pass over each input set.
# Complexity: expected O(a + f + b + p + e + r) time and O(e + r) memory.
shadows() {
	[ -n "${EDIT-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "${BASH_SOURCE[0]}" && return

	local about usage source_path script_dir test_file self_path filter
	about="Report aliases, functions, and PATH binaries that shadow builtins, PATH executables, or each other"
	usage="Usage: shadows [-h|--help] [-a|--about] [--test] [COMMAND]"
	source_path="${BASH_SOURCE[0]}"
	script_dir="$(cd -- "${source_path%/*}" && pwd)"
	test_file="$script_dir/../test/shadows_test"
	self_path="$(cd "$script_dir/.." && pwd)/shadows"

	case "${1-}" in
		-h|--help)
			printf '%s\n' "$usage"
			printf '%s\n' "Print aliases/functions/binaries that take precedence over builtins or PATH commands."
			printf '%s\n' "With no COMMAND, list all known shadows. With COMMAND, inspect only that name."
			return 0
			;;
		-a|--about)
			printf '%s\n' "$about"
			return 0
			;;
		--test)
			"$test_file" >/dev/null
			return $?
			;;
	esac

	filter="${1-}"
	if [[ -n "$filter" ]]; then
		local -a entries paths alias_targets function_targets results
		local -A seen_paths=()
		local line path physical_dir physical_path
		local has_alias=false has_function=false has_builtin=false

		mapfile -t entries < <(builtin type -a -- "$filter" 2>/dev/null)
		alias "$filter" >/dev/null 2>&1 && has_alias=true
		if ((${#entries[@]} == 0)) && ! $has_alias; then
			printf '%s is not defined\n' "$filter"
			return 1
		fi

		for line in "${entries[@]}"; do
			case "$line" in
				"$filter is a function"*)
					has_function=true
					;;
				"$filter is a shell builtin"*)
					has_builtin=true
					;;
				"$filter is hashed ("*)
					path="${line#* (}"
					path="${path%)*}"
					paths+=("$path")
					;;
				"$filter is "*)
					path="${line#"$filter is "}"
					[[ "$path" == /* ]] && paths+=("$path")
					;;
			esac
		done

		for path in "${paths[@]}"; do
			[[ "$path" == "$self_path" ]] && continue
			physical_dir="$(cd -- "${path%/*}" 2>/dev/null && pwd -P)" || physical_dir="${path%/*}"
			physical_path="$physical_dir/${path##*/}"
			[[ -n "${seen_paths[$physical_path]+x}" ]] && continue
			seen_paths[$physical_path]=1
			alias_targets+=("$path")
			function_targets+=("$path")
		done

		$has_function && alias_targets=("function" "${alias_targets[@]}")
		if $has_builtin; then
			alias_targets=("${alias_targets[@]}" "builtin")
			function_targets=("builtin" "${function_targets[@]}")
		fi
		if $has_alias && ((${#alias_targets[@]} > 0)); then
			local joined
			printf -v joined '%s, ' "${alias_targets[@]}"
			results+=("alias $filter shadows: ${joined%, }")
		fi
		if $has_function && ((${#function_targets[@]} > 0)); then
			local joined
			printf -v joined '%s, ' "${function_targets[@]}"
			results+=("function $filter shadows: ${joined%, }")
		fi
		if ((${#paths[@]} > 1)); then
			local first_path=""
			seen_paths=()
			for path in "${paths[@]}"; do
				[[ "$path" == "$self_path" ]] && continue
				physical_dir="$(cd -- "${path%/*}" 2>/dev/null && pwd -P)" || physical_dir="${path%/*}"
				physical_path="$physical_dir/${path##*/}"
				[[ -n "${seen_paths[$physical_path]+x}" ]] && continue
				seen_paths[$physical_path]=1
				if [[ -z "$first_path" ]]; then
					first_path="$path"
				else
					results+=("$first_path shadows: $path")
				fi
			done
		fi

		if ((${#results[@]} == 0)); then
			printf 'Nothing shadows %s\n' "$filter"
			return 0
		fi
		printf '%s\n' "${results[@]}"
		return "${#results[@]}"
	fi

	local -a alias_names function_names builtin_names path_dirs candidate_dirs dir_keys unique_dirs binary_shadow_lines
	local -A functions=() builtins=() seen_dirs=() first_binary=() binary_targets=()
	local line name dir fullpath target count=0

	while IFS= read -r line; do
		name="${line#alias }"
		name="${name%%=*}"
		alias_names+=("$name")
	done < <(alias -p)
	mapfile -t function_names < <(builtin compgen -A function)
	for name in "${function_names[@]}"; do
		functions[$name]=1
	done
	mapfile -t builtin_names < <(builtin compgen -b)
	for name in "${builtin_names[@]}"; do
		builtins[$name]=1
	done

	IFS=':' read -ra path_dirs <<< "$PATH"
	for dir in "${path_dirs[@]}"; do
		[[ -z "$dir" ]] && dir=.
		[[ -d "$dir" ]] || continue
		candidate_dirs+=("$dir")
	done

	local stat_command
	stat_command="$(builtin type -P stat 2>/dev/null)"
	if [[ -n "$stat_command" && "${OSTYPE-}" == darwin* ]]; then
		mapfile -t dir_keys < <("$stat_command" -Lf '%d:%i' -- "${candidate_dirs[@]}" 2>/dev/null)
	elif [[ -n "$stat_command" ]]; then
		mapfile -t dir_keys < <("$stat_command" -Lc '%d:%i' -- "${candidate_dirs[@]}" 2>/dev/null)
	fi
	((${#dir_keys[@]} == ${#candidate_dirs[@]})) || dir_keys=()

	local index dir_key
	for index in "${!candidate_dirs[@]}"; do
		dir="${candidate_dirs[$index]}"
		if ((${#dir_keys[@]} > 0)); then
			dir_key="${dir_keys[$index]}"
		else
			dir_key="$(cd -- "$dir" 2>/dev/null && pwd -P)" || continue
		fi
		[[ -n "${seen_dirs[$dir_key]+x}" ]] && continue
		seen_dirs[$dir_key]=1
		unique_dirs+=("$dir")
	done

	local find_command
	find_command="$(builtin type -P find 2>/dev/null)"
	if [[ -z "$find_command" ]]; then
		printf 'shadows: find is required for an argument-free audit\n' >&2
		return 2
	fi

	local -a find_predicates=(-mindepth 1 -maxdepth 1 -type f)
	if [[ "${OSTYPE-}" == darwin* ]]; then
		find_predicates+=(-perm +111)
	else
		find_predicates+=(-executable)
	fi
	if ((${#unique_dirs[@]} > 0)); then
		while IFS= read -r -d '' fullpath; do
			name="${fullpath##*/}"
			if [[ -n "${binary_targets[$name]+x}" ]]; then
				binary_targets[$name]+=", $fullpath"
				binary_shadow_lines+=("${first_binary[$name]} shadows: $fullpath")
			else
				first_binary[$name]="$fullpath"
				binary_targets[$name]="$fullpath"
			fi
		done < <("$find_command" -L "${unique_dirs[@]}" "${find_predicates[@]}" -print0 2>/dev/null)
	fi

	for name in "${alias_names[@]}"; do
		target=""
		[[ -n "${functions[$name]+x}" ]] && target="function"
		if [[ -n "${builtins[$name]+x}" ]]; then
			target+="${target:+, }builtin"
		fi
		if [[ -n "${binary_targets[$name]+x}" ]]; then
			target+="${target:+, }${binary_targets[$name]}"
		fi
		if [[ -n "$target" ]]; then
			printf 'alias %s shadows: %s\n' "$name" "$target"
			((count++))
		fi
	done

	for name in "${function_names[@]}"; do
		[[ "$name" == shadows ]] && continue
		target=""
		[[ -n "${builtins[$name]+x}" ]] && target="builtin"
		if [[ -n "${binary_targets[$name]+x}" ]]; then
			target+="${target:+, }${binary_targets[$name]}"
		fi
		if [[ -n "$target" ]]; then
			printf 'function %s shadows: %s\n' "$name" "$target"
			((count++))
		fi
	done

	for line in "${binary_shadow_lines[@]}"; do
		printf '%s\n' "$line"
		((count++))
	done

	if ((count > 255)); then
		printf 'Warning: %d shadows detected; exit status capped at 255\n' "$count" >&2
		return 255
	fi
	return "$count"
}

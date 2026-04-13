#!/usr/bin/env bash

shadows() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return

	local about usage script_dir test_file self_path
	about="Report aliases, functions, and PATH binaries that shadow builtins, PATH executables, or each other"
	usage="Usage: shadows [-h|--help] [-a|--about] [--test] [COMMAND]"	script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	test_file="$script_dir/../test/shadows_test"
	self_path="$(cd "$script_dir/.." && pwd)/shadows"

	case "$1" in
		-h|--help)
			echo "$usage"
			echo "Print aliases/functions/binaries that take precedence over builtins or PATH commands."
			echo "If COMMAND is given, only show shadows involving that command name."
			return 0			;;
		-a|--about)
			echo "$about"
			return 0
			;;
		--test)
			"$test_file" >/dev/null
			return $?
			;;
	esac

	local filter="$1"

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

	local collect_binary_shadows
	collect_binary_shadows() {
		local -A seen_binaries  # maps binary name -> first real path
		local -A seen_real_paths  # tracks resolved paths to skip symlink duplicates
		local dir realdir name fullpath realpath
		local -a path_dirs
		IFS=':' read -ra path_dirs <<< "$PATH"
		for dir in "${path_dirs[@]}"; do
			[[ -d "$dir" ]] || continue
			realdir="$(cd "$dir" && pwd -P)"
			while IFS= read -r fullpath; do
				[[ -x "$fullpath" && -f "$fullpath" ]] || continue
				name="${fullpath##*/}"				# Resolve to physical path to detect symlink duplicates
				realpath="$realdir/$name"
				if [[ -n "${seen_real_paths[$realpath]+x}" ]]; then
					# Same physical file via symlinked directory — skip
					continue
				fi
				seen_real_paths[$realpath]=1
				if [[ -n "${seen_binaries[$name]+x}" ]]; then
					# Different physical file with same name — earlier shadows later
					local earlier="${seen_binaries[$name]}"
					results+=("$earlier shadows: $fullpath")
				else
					seen_binaries[$name]="$fullpath"
				fi
			done < <(compgen -G "$dir/*")
		done
	}

	local name
	for name in "${alias_names[@]}"; do		collect_alias_shadows "$name"
	done

	for name in "${function_names[@]}"; do
		[[ "$name" == "shadows" ]] && continue
		collect_function_shadows "$name"
	done

	collect_binary_shadows

	# Apply filter if a command name was given
	if [[ -n "$filter" ]]; then
		local -a filtered
		local line
		for line in "${results[@]}"; do
			if [[ "$line" == "alias $filter shadows:"* ]] || \
			   [[ "$line" == "function $filter shadows:"* ]] || \
			   [[ "$line" == *"/$filter shadows:"* ]]; then
				filtered+=("$line")
			fi
		done
		results=("${filtered[@]}")
		if ((${#results[@]} == 0)); then
			if command -v -- "$filter" > /dev/null 2>&1; then
				echo "Nothing shadows $filter"
				return 0
			else
				echo "$filter is not defined"
				return 1
			fi
		fi
	fi

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

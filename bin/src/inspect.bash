#!/usr/bin/env bash

inspect() {
	local _rWhajSkNUW # Note that this has to be a random variable name due to bash's scoping rules
	local output=""

	for _rWhajSkNUW in "$@"; do
		if declare -p "$_rWhajSkNUW" &>/dev/null; then
			local decl=$(declare -p "$_rWhajSkNUW" 2>&1)

			case "$decl" in
				"declare -a"*)
					# Indexed array
					if [[ "$decl" == *"$_rWhajSkNUW=()"* ]]; then
						# Empty array
						output+="declare -a ${_rWhajSkNUW}=(); "
					else
						# Check if array is declared but unset
						if [[ "$decl" == "declare -a $_rWhajSkNUW" ]]; then
							output+="declare -a ${_rWhajSkNUW}; "
						else
							# Array with values
							local -n ref=$_rWhajSkNUW
							output+="${_rWhajSkNUW}=("
							# local array_part=${decl#*$_rWhajSkNUW=}
							# get only the values
							for value in "${ref[@]}"; do
								# if the value is an integer, don't quote it
								if [[ "$value" =~ ^-?[0-9]+$ ]]; then
									output+=" $value"
								else
									output+=" \"$value\""
								fi
							done
							output+=" ); "
						fi
					fi
					;;
				"declare -A"*)
					# Associative array
					if [[ "$decl" == *"$_rWhajSkNUW=()"* ]]; then
						# Empty associative array
						output+="declare -A ${_rWhajSkNUW}=(); "
					else
						# Check if associative array is declared but unset
						if [[ "$decl" == "declare -A $_rWhajSkNUW" ]]; then
							output+="declare -A ${_rWhajSkNUW}; "
						else
							# Associative array with values
							local array_part=${decl#*$_rWhajSkNUW=}
							# trim last space from before last parens
							array_part=${array_part% )}
							output+="$_rWhajSkNUW=${array_part}); "
						fi
					fi
					;;
				"declare -x"*)
					if [[ "$decl" != *"=\""* ]]; then
						# Exported without value
						output+="export $_rWhajSkNUW; "
					else
						# Exported with value
						local value="${!_rWhajSkNUW}"
						output+="export $_rWhajSkNUW=\"$value\"; "
					fi
					;;
				"declare -i"*)
					# Integer
					local value="${!_rWhajSkNUW}"
					output+="$_rWhajSkNUW=$value; "
					;;
				"declare -r"*)
					# Readonly
					local value="${!_rWhajSkNUW}"
					output+="readonly $_rWhajSkNUW=\"$value\"; "
					;;
				"declare --"*)
					# Regular variable
					local value="${!_rWhajSkNUW}"
					# Check for trailing newlines before processing
					local has_trailing_newline=false
					[[ "${value: -1}" == $'\n' ]] && has_trailing_newline=true

					# Replace real tabs and newlines with \t and \n
					value=$(printf '%s' "$value" | sed 's/\t/\\t/g; s/\n/\\n/g')

					# Add explicit handling for trailing newlines that were detected earlier
					if $has_trailing_newline; then
						value="${value}\\n"
					fi
					output+="$_rWhajSkNUW=\"$value\"; "
					;;
				*)
					output+="$_rWhajSkNUW=\"${!_rWhajSkNUW}\"; "
					;;
				esac
		else
			output+="unset $_rWhajSkNUW; "
		fi
	done

	# trim trailing space using pure bash
	echo "${output% }"
}

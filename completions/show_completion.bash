#!/usr/bin/env bash

# Bail out unless we're in a Bash with programmable completion support
if [ -z "${BASH_VERSION-}" ] || ! type complete >/dev/null 2>&1; then
	return 0 2>/dev/null || exit 0
fi

# Tab completion for show/what commands
_show_completion() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local prev="${COMP_WORDS[COMP_CWORD-1]}"
	
	# Handle --browser option argument
	if [[ "$prev" =~ ^(-b|--browser)$ ]]; then
		COMPREPLY=($(compgen -W "reader clx-reader links browsh" -- "$cur"))
		return
	fi
	
	# Handle options
	if [[ "$cur" == --* ]]; then
		COMPREPLY=($(compgen -W "--help --browser" -- "$cur"))
		return
	elif [[ "$cur" == -* ]]; then
		COMPREPLY=($(compgen -W "-h -b --help --browser" -- "$cur"))
		return
	fi
	
	# Smart completions based on what user has typed
	local suggestions=()
	
	# If it looks like a URL, don't complete
	if [[ "$cur" =~ ^https?:// ]] || [[ "$cur" =~ ^www\. ]]; then
		return
	fi
	
	# If it starts with $, complete variables only
	if [[ "$cur" == \$* ]]; then
		local varname="${cur#\$}"
		suggestions=($(compgen -v -- "$varname" | sed 's/^/$/'))
	# If it contains /, treat as file path
	elif [[ "$cur" == */* ]]; then
		suggestions=($(compgen -f -- "$cur"))
	else
		# Everything else: combine all types
		
		# Variables
		suggestions+=($(compgen -v -- "$cur"))
		
		# Functions
		suggestions+=($(compgen -A function -- "$cur"))
		
		# Aliases - parse from alias command since compgen -a misses many
		if command -v alias >/dev/null 2>&1; then
			suggestions+=($(alias 2>/dev/null | sed -n "s/^alias \([^=]*\)=.*/\1/p" | grep "^$cur" 2>/dev/null))
		fi
		
		# Builtins
		suggestions+=($(compgen -b -- "$cur"))
		
		# Commands in PATH
		suggestions+=($(compgen -c -- "$cur"))
		
		# Files in current directory (only if not too many)
		local file_count=$(ls -1 2>/dev/null | wc -l)
		if [[ $file_count -lt 100 ]]; then
			suggestions+=($(compgen -f -- "$cur"))
		fi
	fi
	
	# Remove duplicates and sort
	if [[ ${#suggestions[@]} -gt 0 ]]; then
		COMPREPLY=($(printf '%s\n' "${suggestions[@]}" | sort -u))
	fi
}

# Register the completion for both show and what commands
complete -F _show_completion show
complete -F _show_completion what
complete -F _show_completion d

#!/usr/bin/env bash

hook() {
	# Handle help and about flags first, before assigning executable_name
	if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
		cat >&2 <<-'EOF'
		Usage: hook [-en|--on-entry <command>] [-ex|--on-exit <command>] <command_or_function>
		
		Wraps a command or function to execute custom commands on entry and/or exit.
		
		Options:
		  -en, --on-entry <cmd>   Execute <cmd> when the hooked function is called
		  -ex, --on-exit <cmd>    Execute <cmd> when the hooked function returns
		
		Template substitutions in <cmd>:
		  __cmd__       - The name of the hooked command/function
		  __args__      - The arguments passed to the command/function
		  __exitcode__  - The exit code (only valid in --on-exit)
		
		If neither -en nor -ex is provided, defaults to yellow stderr logging.
		
		Examples:
		  hook ls                                    # Default yellow logging
		  hook -en "echo 'Called: __cmd__'" date     # Log to stdout on entry
		  hook -ex "echo 'Exit: __exitcode__'" false # Log exit code
		  hook -en "log entry" -ex "log exit" cmd    # Both entry and exit
		EOF
		return 0
	fi
	
	if [[ "$1" == "--about" ]]; then
		echo "Wraps commands/functions to log their invocation and return" >&2
		return 0
	fi
	
	if [[ "$1" == "--test" ]]; then
		"$HOME/dotfiles/bin/test/hook_test" >/dev/null
		return $?
	fi
	
	# Parse arguments
	local entry_cmd=""
	local exit_cmd=""
	local executable_name=""
	
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-en|--on-entry)
				if [[ -z "$2" ]]; then
					echo "Error: $1 requires a command argument" >&2
					return 1
				fi
				# Check for __exitcode__ in entry command
				if [[ "$2" == *"__exitcode__"* ]]; then
					echo "Error: __exitcode__ is not valid in entry commands" >&2
					return 1
				fi
				entry_cmd="$2"
				shift 2
				;;
			-ex|--on-exit)
				if [[ -z "$2" ]]; then
					echo "Error: $1 requires a command argument" >&2
					return 1
				fi
				exit_cmd="$2"
				shift 2
				;;
			-*)
				echo "Error: Unknown option $1" >&2
				return 1
				;;
			*)
				if [[ -n "$executable_name" ]]; then
					echo "Error: Multiple command names provided" >&2
					return 1
				fi
				executable_name="$1"
				shift
				;;
		esac
	done
	
	if [[ -z "$executable_name" ]]; then
		echo "Usage: hook [-en|--on-entry <command>] [-ex|--on-exit <command>] <executable_name>" >&2
		return 1
	fi
	
	# Check if it's already hooked
	if declare -f "_${executable_name}_hook" >/dev/null 2>&1; then
		echo "Error: $executable_name is already hooked" >&2
		return 1
	fi
	
	# Determine the type of command and how to invoke it
	local command_type=""
	local command_invocation=""
	
	if declare -f "$executable_name" >/dev/null 2>&1; then
		command_type="function"
		command_invocation="$executable_name"  # Direct function call
	elif type -t "$executable_name" 2>/dev/null | grep -q "builtin"; then
		command_type="builtin"
		command_invocation="builtin $executable_name"  # Force builtin
	elif command -v "$executable_name" >/dev/null 2>&1; then
		command_type="executable"
		local full_path=$(command -v "$executable_name")
		command_invocation="$full_path"  # Use full path
	else
		echo "Error: $executable_name not found" >&2
		return 1
	fi
	
	# Handle function case - back up existing function and create hook
	if [[ "$command_type" == "function" ]]; then
		# Check if this is already a hook by looking for our hook signatures in the function
		local func_body=$(declare -f "$executable_name")
		if [[ "$func_body" == *"Calling: $executable_name"* ]] && [[ "$func_body" == *"Returned from: $executable_name"* ]]; then
			echo "Error: $executable_name is already hooked" >&2
			return 1
		fi
		
		# Check if the function is exported by testing if it's available in a subshell
		local was_exported=false
		if bash -c "declare -f $executable_name >/dev/null 2>&1"; then
			was_exported=true
		fi
		
		# Back up the existing function
		local func_def=$(declare -f "$executable_name")
		# Replace the function name in the definition with the backup name
		func_def="${func_def/$executable_name/_${executable_name}_hook}"
		eval "$func_def"
		
		# Store export status for unhook to use
		if $was_exported; then
			export -f "_${executable_name}_hook"
			# Create a marker variable to track export status
			declare -g "_${executable_name}_hook_was_exported=true"
		else
			# Create a marker variable to track export status  
			declare -g "_${executable_name}_hook_was_exported=false"
		fi
		
		# Update command_invocation to use the backed-up function
		command_invocation="_${executable_name}_hook"
	fi
	
	# Create the hook function (works for all command types)
	# Do template substitution for command name at creation time
	local entry_template="$entry_cmd"
	local exit_template="$exit_cmd"
	entry_template="${entry_template//__cmd__/$executable_name}"
	exit_template="${exit_template//__cmd__/$executable_name}"
	
	if [[ -n "$entry_cmd" ]] && [[ -n "$exit_cmd" ]]; then
		# Both entry and exit commands
		local func_def
		printf -v func_def 'function %s() {
			local args="$*"
			local entry_cmd=%q
			entry_cmd="${entry_cmd//__args__/$args}"
			eval "$entry_cmd"
			%s "$@"
			local exit_code=$?
			local exit_cmd=%q
			exit_cmd="${exit_cmd//__args__/$args}"
			exit_cmd="${exit_cmd//__exitcode__/$exit_code}"
			eval "$exit_cmd"
			return $exit_code
		}' "$executable_name" "$entry_template" "$command_invocation" "$exit_template"
		eval "$func_def"
	elif [[ -n "$entry_cmd" ]]; then
		# Entry command only
		local func_def
		printf -v func_def 'function %s() {
			local args="$*"
			local entry_cmd=%q
			entry_cmd="${entry_cmd//__args__/$args}"
			eval "$entry_cmd"
			%s "$@"
			return $?
		}' "$executable_name" "$entry_template" "$command_invocation"
		eval "$func_def"
	elif [[ -n "$exit_cmd" ]]; then
		# Exit command only
		local func_def
		printf -v func_def 'function %s() {
			local args="$*"
			%s "$@"
			local exit_code=$?
			local exit_cmd=%q
			exit_cmd="${exit_cmd//__args__/$args}"
			exit_cmd="${exit_cmd//__exitcode__/$exit_code}"
			eval "$exit_cmd"
			return $exit_code
		}' "$executable_name" "$command_invocation" "$exit_template"
		eval "$func_def"
	else
		# Default behavior
		eval "function $executable_name() {
			local args=\"\$*\"
			# Define yellow_text inline if not available
			if ! declare -f yellow_text >/dev/null 2>&1; then
				yellow_text() { echo -e \"\033[93m\$*\033[0m\"; }
			fi
			echo \"\$(yellow_text \"Calling: $executable_name \$args\")\" >&2
			$command_invocation \"\$@\"
			local exit_code=\$?
			echo \"\$(yellow_text \"Returned from: $executable_name \$args\")\" >&2
			return \$exit_code
		}"
	fi
	
	# Export the hook if original was exported (for functions) or always (for builtins/executables)
	if [[ "$command_type" == "function" ]]; then
		if $was_exported; then
			export -f "$executable_name"
		fi
	else
		# Export command hooks so they work in subshells
		export -f "$executable_name"
	fi
	
	echo "Hooked: $executable_name" >&2
}
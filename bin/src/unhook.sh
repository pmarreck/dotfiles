#!/usr/bin/env bash

unhook() {
	# Handle help and about flags first, before assigning executable_name
	if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
		cat >&2 <<-'EOF'
		Usage: unhook <command_or_function>
		
		Removes a hook previously created with the 'hook' command.
		For functions, restores the original function from _<name>_hook backup.
		For commands, simply removes the wrapper function.
		
		Examples:
		  unhook ls           # Remove hook from ls command
		  unhook my_function  # Restore original my_function
		EOF
		return 0
	fi
	
	if [[ "$1" == "--about" ]]; then
		echo "Removes hooks from commands/functions and restores originals" >&2
		return 0
	fi
	
	if [[ "$1" == "--test" ]]; then
		"$HOME/dotfiles/bin/test/unhook_test" >/dev/null
		return $?
	fi
	
	local executable_name="$1"
	if [[ -z "$executable_name" ]]; then
		echo "Usage: unhook <executable_name>" >&2
		return 1
	fi
	
	# Check if the hook exists
	if ! declare -f "$executable_name" >/dev/null 2>&1; then
		echo "No hook found for: $executable_name" >&2
		return 1
	fi
	
	# Check if there's a backup function to restore
	if declare -f "_${executable_name}_hook" >/dev/null 2>&1; then
		# Check if the original was exported
		local was_exported=false
		local export_var="_${executable_name}_hook_was_exported"
		if [[ "${!export_var}" == "true" ]]; then
			was_exported=true
		fi
		
		# Restore the original function
		local func_def=$(declare -f "_${executable_name}_hook")
		# Replace the backup name with the original name
		func_def="${func_def/_${executable_name}_hook/$executable_name}"
		eval "$func_def"
		
		# Restore export status
		if $was_exported; then
			export -f "$executable_name"
		fi
		
		# Clean up backup and marker variable
		unset -f "_${executable_name}_hook"
		unset "$export_var"
	else
		# No backup, so it was a command hook - just remove it
		unset -f "$executable_name"
	fi
	
	echo "Unhooked: $executable_name" >&2
}
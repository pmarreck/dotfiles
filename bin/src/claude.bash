#!/usr/bin/env bash

claude() {
	local claude_path=$(which claude)

	# Handle --noresume flag
	local args=()
	local should_resume=true
	for arg in "$@"; do
		if [ "$arg" = "--noresume" ]; then
			should_resume=false
		else
			args+=("$arg")
		fi
	done
	set -- "${args[@]}"

	# if there are any arguments, just use them
	if [ $# -gt 0 ]; then
		puts --yellow --stderr $claude_path "$@"
		$claude_path "$@"
	else
		warn "Running claude with unlimited privileges!"
		# if there is not a .git directory, output an additional warning about setting up git
		if [ ! -d .git ]; then
			warn "No .git directory found. Please initialize a git repository before running claude with unlimited privileges to capture all changes automatically."
		fi

		if [ "$should_resume" = true ]; then
			warn "$claude_path --resume --dangerously-skip-permissions"
			$claude_path --resume --dangerously-skip-permissions
		else
			warn "$claude_path --dangerously-skip-permissions"
			$claude_path --dangerously-skip-permissions
		fi
	fi
}

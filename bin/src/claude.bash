#!/usr/bin/env bash

claude() {
	# if there are any arguments, just use them
	local claude_path=$(which claude)
	if [ $# -gt 0 ]; then
		puts --yellow --stderr $claude_path "$@"
		$claude_path "$@"
	else
		warn "Running claude with unlimited privileges!"
		# if there isn't a .jj directory, output an additional warning about setting up jujutsu
		if [ ! -d .jj ]; then
			warn "No .jj directory found. Please initialize a jujutsu repository before running claude with unlimited privileges to capture all changes automatically."
		fi
		warn "$claude_path --resume --dangerously-skip-permissions"
		$claude_path --resume --dangerously-skip-permissions
	fi
}

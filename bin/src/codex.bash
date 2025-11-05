#!/usr/bin/env bash

codex() {
	# if there are any arguments, just use them
	local codex_path=$(which codex)
	if [ $# -gt 0 ]; then
		puts --yellow --stderr $codex_path "$@"
		$codex_path "$@"
	else
		warn "Running codex with unlimited privileges!"
		# if there isn't a .jj directory, output an additional warning about setting up jujutsu
		if [ ! -d .jj ]; then
			warn "No .jj directory found. Please initialize a jujutsu repository before running codex with unlimited privileges to capture all changes automatically."
		fi
		warn "$codex_path resume --enable web_search_request --dangerously-bypass-approvals-and-sandbox"
		$codex_path resume --enable web_search_request --dangerously-bypass-approvals-and-sandbox
	fi
}

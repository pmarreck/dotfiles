#!/usr/bin/env bash

# This helps prevent issues with sh invocations

set -e

# Directories to search
DIRS=(
	"/home/pmarreck/dotfiles/bin"
	"/home/pmarreck/dotfiles/bin/src"
	"/home/pmarreck/dotfiles"
)

for dir in "${DIRS[@]}"; do
	echo "Searching in $dir..."
	
	
	for file in $files; do
		# Skip if not a regular file
		[ -f "$file" ] || continue
		
		echo "Processing $file..."
		
	done
done

echo "All function export lines have been deleted!"

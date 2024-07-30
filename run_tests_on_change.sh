#!/usr/bin/env bash

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# echo "Script directory: $SCRIPT_DIR"
# Path to store the hash
HASH_FILE="$HOME/.dotfile_hash"

# Calculate the current hash
# Use xxhsum if it exists, otherwise md5sum
hasher="md5sum"
if command -v xxhsum &> /dev/null; then
  hasher="xxhsum"
fi
# echo "Using hasher: $hasher"
# Get the hash of all text files in the dotfiles directory
CURRENT_HASH=$(stat -c "%Y" $(file --separator " :" $(fd --type f --no-hidden --exclude .git --exclude "Library/" . $SCRIPT_DIR) | grep text | cut -d':' -f1 | sort) | $hasher | cut -d' ' -f1)
# echo "Current hash: $CURRENT_HASH"
# Check if the hash file exists
if [ -f "$HASH_FILE" ]; then
  # Read the stored hash
  STORED_HASH=$(cat "$HASH_FILE")
else
  # If hash file doesn't exist, initialize it
  STORED_HASH=""
fi

# Compare the current hash with the stored hash
if [ "$CURRENT_HASH" != "$STORED_HASH" ] || [ "$RUN_DOTFILE_TESTS" = "true" ]; then
  [ "$CURRENT_HASH" != "$STORED_HASH" ] && echo -n "Files have changed. "
  echo "Enabling dotfile runtime tests..."
  RUN_DOTFILE_TESTS=true
  echo "$CURRENT_HASH" > "$HASH_FILE"
fi

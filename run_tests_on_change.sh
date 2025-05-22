#!/usr/bin/env bash

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
truthy DEBUG_SHELLCONFIG && echo "Script directory for run_tests_on_change: $SCRIPT_DIR"
# Path to store the hash
HASH_FILE="$HOME/.dotfile_hash"

# Calculate the current hash
# Use xxhsum if it exists, otherwise md5sum
hasher="md5sum"
if command -v xxhsum &> /dev/null; then
  hasher="xxhsum"
fi
truthy DEBUG_SHELLCONFIG && echo "Using hasher: $hasher"
# Use GNU stat installed via nix-darwin or nixos if it exists, otherwise use BSD stat
# first look for gstat anywhere in path
if command -v gstat &> /dev/null; then
  statter="gstat -c %Y"
# then look for stat in /run/current-system/sw/bin
elif [ -f /run/current-system/sw/bin/stat ]; then
  statter="/run/current-system/sw/bin/stat -c %Y"
# then try to see if an option only available on gnu stat errors
elif stat -c %Y / 2>/dev/null; then
  statter="stat -c %Y"
# else just assume bsd stat
else
  statter="/usr/bin/stat -f %m"
fi
truthy DEBUG_SHELLCONFIG && echo "Using statter: $statter"
# Get the hash of all text files in the dotfiles directory
CURRENT_HASH=$($statter $(file --separator " :" $(fd --type f --no-hidden --exclude .git --exclude "Library/" . $SCRIPT_DIR) | grep text | cut -d':' -f1 | sort) | $hasher | cut -d' ' -f1)
truthy DEBUG_SHELLCONFIG && echo "Current hash: $CURRENT_HASH"
# Check if the hash file exists
if [ -f "$HASH_FILE" ]; then
  # Read the stored hash
  STORED_HASH=$(cat "$HASH_FILE")
else
  # If hash file doesn't exist, initialize it
  STORED_HASH=""
fi
truthy DEBUG_SHELLCONFIG && echo "Stored hash: $STORED_HASH"

# Skip test runs if SKIP_DOTFILE_TESTS is set (used during rehash)
if truthy SKIP_DOTFILE_TESTS; then
  export RUN_DOTFILE_TESTS=false
  echo "Skipping dotfile tests due to SKIP_DOTFILE_TESTS flag."
  exit 0
fi

# Compare the current hash with the stored hash
if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
  echo -n "Dotfiles have changed. Hash '$CURRENT_HASH' != '$STORED_HASH'. "
  export RUN_DOTFILE_TESTS=${RUN_DOTFILE_TESTS:-true}
  echo -n "$CURRENT_HASH" > "$HASH_FILE"
else
  truthy DEBUG_SHELLCONFIG && echo -n "Dotfiles have not changed. Hash '$CURRENT_HASH' == '$STORED_HASH'. "
  export RUN_DOTFILE_TESTS=${RUN_DOTFILE_TESTS:-false}
fi

# If tests are enabled but test output is suppressed, run silently
if truthy RUN_DOTFILE_TESTS; then
  if truthy TEST_VERBOSE; then
    echo "Enabling dotfile tests with output..."
  else
    echo "Running dotfile tests silently..."
    export TEST_VERBOSE=false
    export EXPAND_TEST_VERBOSE=false
  fi
else
  if truthy DEBUG_SHELLCONFIG; then
    echo "Skipping dotfile tests."
  fi
fi

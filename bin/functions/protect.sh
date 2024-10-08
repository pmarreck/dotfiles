#!/usr/bin/env bash

# Path to the undo log
: "${UNDO_LOG:=$HOME/.protect_undo.log}"

# Custom function to log the undo command
log_undo() {
  echo "$1|$2" >> "$UNDO_LOG" || error_exit "Unable to write to undo log at $UNDO_LOG"
}

# Custom function to handle errors
error_exit() {
  echo "[ERROR] $1" >&2
  exit 1
}

debug() {
  [ -n "$DEBUG" ] && echo "DEBUG: $1" >&2
}

# Function to get absolute path
get_abs_path() {
  local rel_path="$1"
  echo "$(cd "$(dirname "$rel_path")" && pwd)/$(basename "$rel_path")"
}

# Function to calculate XOR difference between permission bits
xor_diff() {
  local original=$1
  local current=$2

  # Split the permission bits into user, group, and other
  local original_user=$(( (original / 100) % 10 ))
  local original_group=$(( (original / 10) % 10 ))
  local original_other=$(( original % 10 ))

  local current_user=$(( (current / 100) % 10 ))
  local current_group=$(( (current / 10) % 10 ))
  local current_other=$(( current % 10 ))

  # XOR each component individually
  local diff_user=$(( current_user - original_user ))
  local diff_group=$(( current_group - original_group ))
  local diff_other=$(( current_other - original_other ))
  # Combine the diffs back into a single value
  echo "$diff_user$diff_group$diff_other"
}

# Function to handle chmod (per file)
protect_chmod() {
  local mode="$1"
  local file="$2"

  local absfile
  absfile=$(get_abs_path "$file") && debug "Absolute path for $file: $absfile"

  if [[ -e "$absfile" ]]; then
    debug "File found: $absfile"
    original_perms=$(stat -c "%a" "$absfile") && debug "Original permissions for $absfile: $original_perms"
    chmod "$mode" "$absfile" && debug "Ran chmod $mode on $absfile"
    current_perms=$(stat -c "%a" "$absfile") && debug "Current permissions for $absfile after chmod: $current_perms"

    if [[ "$original_perms" -ne "$current_perms" ]]; then
      diff=$(xor_diff $original_perms $current_perms)
      debug "Calculated diff: $diff"
      log_undo "$diff" "$absfile"
    else
      debug "No change in permissions; skipping undo log"
    fi
  else
    error_exit "File not found: $file"
  fi
}

# Expand globs before running protect
expand_globs() {
  local expanded=()
  for file in "$@"; do
    expanded+=( $(eval echo "$file") )
  done
  printf "%s\n" "${expanded[@]}"
}

# Main protect function
protect() {
  local cmd="$1"
  shift

  case "$cmd" in
    chmod)
      debug "chmod command detected"
      local mode="$1"
      shift
      expanded_files=$(expand_globs "$@") && debug "Expanded files: $expanded_files"
      while IFS= read -r file; do
        protect_chmod "$mode" "$file" && debug "protect_chmod did not error on file $file"
      done <<< "$expanded_files"
      ;;
    undo)
      debug "undo command detected"
      local diff
      local file
      while IFS='|' read -r diff file; do
        [[ -z "$diff" || -z "$file" ]] && continue  # Skip empty lines
        if [[ -e "$file" ]]; then
          current_perms=$(stat -c "%a" "$file") && debug "Current permissions for $file: $current_perms"

          # Calculate original permissions using XOR diff
          original_user=$(( ((current_perms / 100) % 10 - (diff / 100) % 10 + 8) % 8 ))
          original_group=$(( ((current_perms / 10) % 10 - (diff / 10) % 10 + 8) % 8 ))
          original_other=$(( (current_perms % 10 - diff % 10 + 8) % 8 ))
          original_perms="$original_user$original_group$original_other"
          debug "Calculated original permissions: $original_perms"
          debug "Calculated original permissions: $original_perms"
          chmod "$original_perms" "$file" && debug "Reverted permissions on $file to $original_perms"
        else
          error_exit "File not found during undo: $file"
        fi
      done < "$UNDO_LOG"
      ;;
    *)
      error_exit "Not sure how to undo command: $cmd"
      ;;
  esac
}

# Test functions if the script is run with 'test' argument
test_protect() {
  echo "Running tests..."
  local test_dir=$(mktemp -d -t test_protect_dir.XXXXXX)
  local test_file="$test_dir/testfile.txt"
  touch "$test_file"
  chmod 644 "$test_file"
  protect chmod u+x "$test_file"
  local current_perms=$(stat -c "%a" "$test_file")
  if [[ "$current_perms" == "744" ]]; then
    echo "Test passed: chmod u+x"
  else
    echo "Test failed: chmod u+x"
  fi
  protect undo
  local reverted_perms=$(stat -c "%a" "$test_file")
  if [[ "$reverted_perms" == "644" ]]; then
    echo "Test passed: undo chmod u+x"
  else
    echo "Test failed: undo chmod u+x"
  fi
  rm -rf "$test_dir"
}

# Run the function, passing along any args, if this file was run directly
_me=$(basename "${0##\-}")
if [ "$_me" = "protect" ]; then
  protect "$@"
elif [ "$1" = "test" ]; then
  test_protect
fi
unset _me

#!/usr/bin/env bash

# Function to run a test suite and report results in a standardized way
run_test_suite() {
  local test_name="${1:-${0##*/}}"
  local failed=false
  local setup_fn="${2:-:}"    # Optional setup function
  local test_fn="$3"         # The actual test function
  local teardown_fn="${4:-:}" # Optional teardown function
  local test_count=0
  local pass_count=0
  local fail_count=0
  local verbose=${TEST_VERBOSE:-false}

  # Run tests in a subshell to capture failures
  if (
    # Run setup if provided
    $setup_fn

    # Run the test function if provided, otherwise assume tests are inline
    if [[ -n "$test_fn" ]]; then
      $test_fn
    else
      return 0  # No test function provided means success (inline tests handle their own returns)
    fi

    # If we get here, all tests passed
    true
  ); then
    if [[ -n "$test_fn" ]]; then
      $verbose && printf "\033[32m%s: PASS\033[0m\n" "$test_name"
      ((pass_count++))
    fi
  else
    # Always show failures, even in non-verbose mode
    printf "\033[31m%s: FAIL\033[0m\n" "$test_name"
    ((fail_count++))
    failed=true
  fi

  # Run teardown if provided
  $teardown_fn

  # Update total test count
  test_count=$((pass_count + fail_count))

  # If this is the last test suite being run, show a summary (only in verbose mode unless there are failures)
  # Use -- to ensure basename treats $0 as a filename even if it starts with a dash
  if [[ "$test_name" == "$(basename -- "$0")" && ($verbose == true || $fail_count -gt 0) ]]; then
    printf "\nTest Summary:\n"
    printf "Total Tests: %d\n" $test_count
    printf "\033[32mPassed: %d\033[0m\n" $pass_count
    if [[ $fail_count -gt 0 ]]; then
      printf "\033[31mFailed: %d\033[0m\n" $fail_count
    fi
  fi

  $failed && return 1 || return 0
}

export -f run_test_suite

if truthy DEBUG_SHELLCONFIG; then
  echo "Loaded test_reporter.bash"
fi

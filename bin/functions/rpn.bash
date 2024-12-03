#!/usr/bin/env bash
# file: rpn.bash

reverse_args() {
	echo "$@" | tr ' ' '\n' | tac | tr '\n' ' '
}
export -f reverse_args

rpn() {
	if [ -p /dev/stdin ]; then
		# If data is piped, read it as a single line
		input=$(cat)
		reverse_args $input | gawk -f "$(dirname "${BASH_SOURCE[0]}")/rpn.awk"
	else
		# Otherwise, process the arguments directly
		reverse_args "$@" | gawk -f "$(dirname "${BASH_SOURCE[0]}")/rpn.awk"
	fi
}
export -f rpn

test_rpn() {
	local input="$1"
	local expected="$2"
	local result
	result=$(echo "$input" | rpn 2>&1)
	if [[ "$result" == "$expected" ]]; then
		echo "✓ Test passed: '$input' -> '$result'"
		return 0
	else
		echo "✗ Test failed in $(dirname "${BASH_SOURCE[0]}"): '$input'" >&2
		echo "  Expected: '$expected'" >&2
		echo "  Got:      '$result'" >&2
		return 1
	fi
}

run_test() {
	local errors=0
	# Basic arithmetic
	test_rpn "2 3 + ." "5"
	((errors += $?))
	test_rpn "5 3 - ." "2"
	((errors += $?))
	test_rpn "4 2 \* ." "8"
	((errors += $?))
	test_rpn "6 2 / ." "3"
	((errors += $?))

	# Stack operations
	test_rpn "2 dup + ." "4"
	((errors += $?))
	test_rpn "1 2 swap + ." "3"
	((errors += $?))
	test_rpn "1 2 3 drop + ." "3"
	((errors += $?))

	# Complex operations
	test_rpn "15 7 1 1 + - / 3 \* 2 1 1 + + - ." "5"
	((errors += $?))

	# Strings
	test_rpn "\"hello\" ." "hello"
	((errors += $?))

	# Bitwise operations
	test_rpn "1 2 and ." "0"
	((errors += $?))
	test_rpn "1 2 or ." "3"
	((errors += $?))
	test_rpn "1 3 xor ." "2"
	((errors += $?))

	# Peek prints
	test_rpn "69 .s .s ." "69
69
69"
	((errors += $?))

	# Error cases
	test_rpn "+" "Error: Stack underflow"
	((errors += $?))
	test_rpn "1 2 + +" "Error: Stack underflow"
	((errors += $?))
	test_rpn "1 0 /" "Error: Division by zero"
	((errors += $?))

	return $errors
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  run_test > /dev/null
fi

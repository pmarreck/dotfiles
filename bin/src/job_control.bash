#!/usr/bin/env bash

declare -F debug >/dev/null 2>&1 || 
debug() {
  [ -n "$DEBUG" ] && echo "DEBUG: $*" >&2
}

sequentialize() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return

	function _seq_usage {
		echo "Usage: sequentialize \"<command with {} placeholder>\" <args...>"
		echo "       sequentialize [-h|--help]"
		echo "       sequentialize test"
	}

	function _seq_example {
		echo "Example: sequentialize \"echo -n {}\" foo bar baz  #=> foobarbaz"
	}

	function _seq_help {
		echo "sequentialize: Executes the given command sequentially, replacing any '{}' in the first argument"
		echo "with each of the subsequent arguments."
		echo "(I wanted something with a nicer API than xargs...)"
		_seq_usage
		_seq_example
	}

	function _seq_test {
		local expected_out expected_err actual_out actual_err
		# Test 1: Basic sequential execution
		expected_out=$'hello\nworld'
		actual_out=$(sequentialize "echo {}" "hello" "world")
		if [[ "$actual_out" != "$expected_out" ]]; then
			printf "Test 1 failed:\nExpected: '%s'\nGot:      '%s'\n" "$expected_out" "$actual_out" >&2
			return 1
		fi

		# Test 2: ANSI color codes
		expected_out=$'\033[32mgreen\033[0m\n\033[31mred\033[0m'
		actual_out=$(sequentialize 'echo -e "\033[32m{}\033[0m"' "green" && sequentialize 'echo -e "\033[31m{}\033[0m"' "red")
		if [[ "$actual_out" != "$expected_out" ]]; then
			echo "Test 2 failed: ANSI codes not preserved" >&2
			printf "Expected (hex): %s\n" "$(echo -n "$expected_out" | xxd -p)" >&2
			printf "Got (hex):      %s\n" "$(echo -n "$actual_out" | xxd -p)" >&2
			printf "Expected (raw): '%s'\n" "$expected_out" >&2
			printf "Got (raw):      '%s'\n" "$actual_out" >&2
			return 1
		fi

		# Test 3: stderr output
		expected_err=$'error1\nerror2'
		actual_err=$(sequentialize "echo {} >&2" "error1" "error2" 2>&1)
		if [[ "$actual_err" != "$expected_err" ]]; then
			printf "Test 3 failed:\nExpected: '%s'\nGot:      '%s'\n" "$expected_err" "$actual_err" >&2
			return 1
		fi

		return 0
	}

	case "$1" in
		-h|--help)
			_seq_usage
			return 0
			;;
		test)
			_seq_test
			return $?
			;;
	esac

	if [ $# -lt 2 ]; then
		echo "Error: At least 2 arguments required (command and at least one argument)" >&2
		_seq_usage >&2
		return 2
	fi

	local cmd="$1"
	shift
	local total_exit_code=0
	for arg in "$@"; do
		eval "${cmd//\{\}/\"$arg\"}"
		total_exit_code=$((total_exit_code + $?))
	done
	return $total_exit_code
}

parallelize() {
	function _par_usage {
		echo "Usage: parallelize \"<command with {} placeholder>\" <args...>"
		echo "       parallelize [-h|--help]"
		echo "       parallelize test"
	}

	function _par_example {
		echo "Example: parallelize \"echo {}\" foo bar baz  # Output order not guaranteed"
	}

	function _par_help {
		echo "parallelize: Executes the given command concurrently, replacing any '{}' in the first argument"
		echo "with each of the subsequent arguments. Output order is not guaranteed."
		echo "Like a mini GNU parallel, but one less dependency."
		echo "(API is similar to sequentialize function.)"
		_par_usage
		_par_example
	}

	function _par_test {
		local expected_out expected_err actual_out actual_err combined_out
		# Test 1: Basic parallel execution
		expected_out=$'foo\nbar'
		actual_out=$(parallelize "echo {}" "foo" "bar" | sort)
		expected_out=$(echo "$expected_out" | sort)
		if [[ "$actual_out" != "$expected_out" ]]; then
			printf "Test 1 failed:\nExpected: '%s'\nGot:      '%s'\n" "$expected_out" "$actual_out" >&2
			return 1
		fi

		# Test 2: ANSI color codes
		expected_out=$'\033[32mgreen\033[0m\n\033[31mred\033[0m'
		actual_out=$(parallelize 'echo -e "\033[32m{}\033[0m"' "green" && parallelize 'echo -e "\033[31m{}\033[0m"' "red" | sort)
		if [[ "$actual_out" != "$expected_out" ]]; then
			echo "Test 2 failed: ANSI codes not preserved" >&2
			printf "Expected (hex): %s\n" "$(echo -n "$expected_out" | xxd -p)" >&2
			printf "Got (hex):      %s\n" "$(echo -n "$actual_out" | xxd -p)" >&2
			printf "Expected (raw): '%s'\n" "$expected_out" >&2
			printf "Got (raw):      '%s'\n" "$actual_out" >&2
			return 1
		fi

		# Test 3: stderr output
		expected_err=$'error1\nerror2'
		actual_err=$(parallelize "echo {} >&2" "error1" "error2" 2>&1 | sort)
		if [[ "$actual_err" != "$expected_err" ]]; then
			printf "Test 3 failed:\nExpected: '%s'\nGot:      '%s'\n" "$expected_err" "$actual_err" >&2
			return 1
		fi

		# Test 4: Mixed stdout/stderr
		combined_out=$(parallelize "echo out_{}; echo err_{} >&2" "1" "2" > >(sort) 2> >(sort))
		expected_out=$'out_1\nout_2'
		expected_err=$'err_1\nerr_2'
		actual_out=$(echo "$combined_out" | grep "^out" | sort)
		actual_err=$(echo "$combined_out" | grep "^err" | sort)
		if [[ "$actual_out" != "$expected_out" ]]; then
			printf "Test 4 failed stdout:\nExpected: '%s'\nGot:      '%s'\n" "$expected_out" "$actual_out" >&2
			return 1
		fi
		if [[ "$actual_err" != "$expected_err" ]]; then
			printf "Test 4 failed stderr:\nExpected: '%s'\nGot:      '%s'\n" "$expected_err" "$actual_err" >&2
			return 1
		fi

		return 0
	}

	# main dispatch

	case "$1" in
		-h|--help)
			_par_usage
			return 0
			;;
		test)
			_par_test
			return $?
			;;
	esac

	if [ $# -lt 2 ]; then
		echo "Error: At least 2 arguments required (command and at least one argument)" >&2
		_par_usage >&2
		return 2
	fi

	# main function

	local cmd="$1"
	shift
	local total_exit_code=0
	local processes=()
	local results=()

	# Default concurrency: Use number of CPU cores, or 4 otherwise
	local concurrency=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
	# debug "Concurrency: $concurrency"
	local running_jobs=0

	local prev_job_control
	prev_job_control=$(shopt -po monitor)
	set +m  # Disable job termination messages
	exec 3>&2 2>/dev/null  # Suppress job creation messages by blackholing stderr but capturing fd3 from subprocesses
	local whichwait
	if ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))); then
		whichwait="wait -n" # Wait for any job to finish; requires Bash 5.1+
	else
		whichwait='while [[ $(jobs | wc -l) -ge $concurrency ]]; do sleep 0.1; done'
	fi
	# debug "whichwait: $whichwait" 2>&3

	for arg in "$@"; do
		(
			# Force color output by ensuring TERM is set
			TERM=${TERM:-xterm-256color} eval "${cmd//\{\}/\"$arg\"}" 2>&3 # Send stderr to fd3 due to above setup
			exit $?
		) & processes+=($!)
		((running_jobs++))

		if ((running_jobs >= concurrency)); then
			# debug "Waiting for 1 job to finish" 2>&3
			$whichwait
			# debug "Done waiting" 2>&3
			((running_jobs--))
		fi
	done

	exec 2>&3 3>&-  # Restore stderr

	for pid in "${processes[@]}"; do
		wait "$pid"
		total_exit_code=$((total_exit_code + $?))
	done

	eval "$prev_job_control"  # Restore previous job control state
	return $total_exit_code
}

# Here's a fun manual test:
# echo_rand_color() { colors=(30 31 32 33 34 35 36 37 90 91 92 93 94 95 96 97); echo -e "\e[${colors[RANDOM % ${#colors[@]}]}m$*\e[0m"; }
# parallelize 'sleep $(echo "scale=3; $RANDOM/32768*2" | bc) && echo_rand_color {}' Four score and seven years ago, our fathers brought forth on this Continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal. Now we are engaged in a great civil war, testing whether that nation, or any nation so conceived and so dedicated, can long endure. We are met on a great battle-field of that war. We have come to dedicate a portion of that field, as a final resting place for those who here gave their lives that that nation might live. It is altogether fitting and proper that we should do this. But, in a larger sense, we can not dedicate -- we can not consecrate -- we can not hallow -- this ground. The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract. The world will little note, nor long remember what we say here, but it can never forget what they did here. It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced. It is rather for us to be here dedicated to the great task remaining before us -- that from these honored dead we take increased devotion to that cause for which they gave the last full measure of devotion -- that we here highly resolve that these dead shall not have died in vain -- that this nation, under God, shall have a new birth of freedom -- and that government of the people, by the people, for the people, shall not perish from the earth.

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
	if sequentialize test; then
		if parallelize test; then
			return 0
		else
			echo "Parallelize test failed!" >&2
			return 1
		fi
	else
		echo "Sequentialize test failed!" >&2
		return 1
	fi
fi

capture() {
	local use_printable_binary=0
	while [ $# -gt 0 ]; do
		case "${1-}" in
			-p|--printable-binary)
				use_printable_binary=1
				shift
				;;
			--test)
				# Run tests in a subshell to avoid polluting the current environment
				(
					local test_file
					test_file="$(dirname "${BASH_SOURCE[0]}")/test/capture_test"
					if [[ -f "$test_file" ]]; then
						# Since this script is now sourced, the test must also source it.
						exec "$test_file" >/dev/null
					else
						echo "Test file not found: $test_file" >&2
						exit 127
					fi
				)
				return $?
				;;
			-a|--about)
				echo "capture: capture stdout, stderr, and return/exit code into pre-declared vars: out, err, rc."
				return 0
				;;
			-h|--help)
				cat <<'EOF'
usage: capture [-p|--printable-binary] [--] command [args...]

Runs the command and captures:
	- stdout -> variable: out
	- stderr -> variable: err
	- return/exit code -> variable: rc

Options:
	-p, --printable-binary
		Process stdout and stderr through the `printable_binary` utility
		to make them safe for storing in Bash variables (handles NULs
		and other control characters). It can also decode printable_binary
		output back into a string or to a file via `printable_binary -d`.

Requirements:
	- This function must be sourced.
	- Bash 4.0+ (for printf %q).
	- In the caller's scope, variables "out", "err", and "rc" must already exist, e.g.:

			local out err rc
			capture some_command ...

	- To run a command whose name starts with "-", use:

			capture -- -weirdcmd ...
EOF
				return 0
				;;
			--)
				shift
				break
				;;
			*) # Unknown argument or option
				break
				;;
		esac
	done
	if [[ $# -eq 0 ]]; then
		printf 'capture: no command given\n' >&2
		return 2
	fi
	# Check for printable_binary if requested
	local _old_pb_mute_stats
	if (( use_printable_binary )); then
		if ! command -v printable_binary &> /dev/null; then
			printf 'capture: command not found: printable_binary\n' >&2
			return 127
		fi
		# Mute printable_binary's statistics output that goes to stderr, if not already muted
		_old_pb_mute_stats=$PRINTABLE_BINARY_MUTE_STATS
		export PRINTABLE_BINARY_MUTE_STATS=true
	fi
	# Verify that out/err/rc exist in the dynamic scope (caller locals or globals)
	local v
	for v in out err rc; do
		# Using declare -p is more robust for checking variable existence across scopes.
		if ! declare -p "$v" &>/dev/null; then
			printf 'capture: required variable "%s" is not declared in caller scope\n' "$v" >&2
			return 2
		fi
	done
	(( use_printable_binary )) && _filter="printable_binary" || _filter="cat"
	local __out __err __rc
	# We source the output of the block, which contains 'declare -- __out="..."' etc.
	# FD 3 is used to route filtered stderr around the inner stdout capture.
	# FD 4 is used to route the variable definitions to the 'source' command.
	. <(
		{
			__err=$(
				{
					__out=$(
						set -o pipefail
						# A. Run command
						# B. Redirect Stderr -> Process Sub (Filter -> FD 3)
						# C. Pipe Stdout -> Filter -> Stdout (Captured by __out=)
						"$@" 2> >($_filter >&3) | $_filter
					)
					__rc=$?
					
					# D. Send captured __out and __rc to FD 4
					declare -p __out __rc >&4
				} 3>&1 
				# E. Redirect FD 3 (Filtered Stderr) back to FD 1 for __err=$()
			)
			# F. Send captured __err to FD 4
			declare -p __err >&4
			
		} 4>&1
	)

	# Restore printable_binary's statistics output that goes to stderr, if not already muted
	if (( use_printable_binary )); then
		export PRINTABLE_BINARY_MUTE_STATS="$_old_pb_mute_stats"
	fi

	# Transfer the data from our safe locals to the caller's variables.
	out="$__out"
	err="$__err"
	rc="$__rc"
}

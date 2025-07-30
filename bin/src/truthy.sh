#!/bin/sh

# Define the falsey function; keep it POSIX-compatible
falsey() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "$0" "$0" && return

	# Our normal env "debug" function actually depends on truthy/falsey so we define one specific to here
	_truthy_free_debug() {
		local debug_state
		# if DEBUG is NOT set to anything, assume false
		if [ -z "${DEBUG}" ]; then
			debug_state=false
		else
			# if DEBUG is set to any value other than 0, false, off, n, no, disable, disabled, set it to true
			if [ "${DEBUG}" != 0 ] && [ "${DEBUG}" != false ] && [ "${DEBUG}" != off ] && [ "${DEBUG}" != n ] && [ "${DEBUG}" != no ] && [ "${DEBUG}" != disable ] && [ "${DEBUG}" != disabled ]; then
				debug_state=true
			else
				debug_state=false
			fi
		fi
		# now we can assume debug_state is always set to either true or false
		if $debug_state; then
			echo -e "\033[33mDEBUG: $*\033[0m" >&2
		else
			:
		fi
	}

	# Print help for truthy/falsey
	truthy_help() {
		cat <<EOF
Usage: truthy VARIABLE_NAME
Returns 0 (success) if VARIABLE_NAME is not falsey. Returns 1 otherwise.

Usage: falsey VARIABLE_NAME
Returns 0 (success) if VARIABLE_NAME is unset, or is set to a "falsey" value (0, false, off, n, no, disable, disabled). Returns 1 otherwise.

Options:
  --help    Show this help message
  --test    Run the test suite for this function
EOF
}
  case "$1" in
    --help)
      truthy_help
      return 0
      ;;
    --test)
      "$HOME/dotfiles/bin/test/falsey_test"
      return $?
      ;;
  esac

	var_name="$1"

	# 1. Validate the variable name (POSIX regex emulation with `case`)
	case "$var_name" in
		[!a-zA-Z_]*|*[!a-zA-Z0-9_]*)
			err "Error from truthy/falsey: '$var_name' is not a valid shell variable name"
			return 2
			;;
	esac

	# 2. Check if the variable exists; if not, return true immediately
	# (nonexistent variables are falsey)
	if ! eval "[ \"\${$var_name+set}\" = set ]"; then
	  # _truthy_free_debug "Variable \"$var_name\" is not set and thus falsey"
	  return 0
	fi

	# 3. Retrieve the variable value (POSIX-compatible eval)
	value=$(eval "printf '%s\n' \"\$$var_name\"")
	# _truthy_free_debug "Value of \"$var_name\": \"$value\""

	# 4. Convert value to lowercase (POSIX-compatible using tr)
	lower_value=$(printf '%s' "$value" | tr 'A-Z' 'a-z')
	# _truthy_free_debug "Lowercase value of \"$var_name\": \"$lower_value\""

	# 5. Check if the value is "falsey"
	case "$lower_value" in
		0|f|false|off|n|no|disable|disabled)
			# _truthy_free_debug "\"$var_name\" is falsey"
			return 0
			;;
		# If it exists and is not falsey, it is truthy
		*)
			# _truthy_free_debug "\"$var_name\" is truthy"
			return 1
			;;
	esac
  unset var_name value lower_value
}

# Define the truthy function in terms of the falsey function
truthy() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "$0" "$0" && return

  case "$1" in
    --help|--test)
      falsey "$1"
      return 0
      ;;
    *)
      falsey "$1"
      rc=$?
      if [ "$rc" -eq 0 ]; then
        return 1
      elif [ "$rc" -eq 1 ]; then
        return 0
      else
        return $rc
      fi
      ;;
  esac
  unset rc
}

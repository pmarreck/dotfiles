#!/bin/sh

# Define the falsey function; keep it POSIX-compatible
falsey() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "$0" "$0" && return

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
	  debug "Variable \"$var_name\" is not set and thus falsey"
	  return 0
	fi

	# 3. Retrieve the variable value (POSIX-compatible eval)
	value=$(eval "printf '%s\n' \"\$$var_name\"")
	debug "Value of \"$var_name\": \"$value\""

	# 4. Convert value to lowercase (POSIX-compatible using tr)
	lower_value=$(printf '%s' "$value" | tr 'A-Z' 'a-z')
	debug "Lowercase value of \"$var_name\": \"$lower_value\""

	# 5. Check if the value is "falsey"
	case "$lower_value" in
		0|f|false|off|n|no|disable|disabled)
			debug "\"$var_name\" is falsey"
			return 0
			;;
		# If it exists and is not falsey, it is truthy
		*)
			debug "\"$var_name\" is truthy"
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

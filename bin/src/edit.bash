#!/usr/bin/env bash

edit() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	if contains "$(functions)" $1; then
		EDIT=1 $1
	else
		choose_editor "$@"
	fi
}

# Run the function if this script is executed directly
if ! (return 0 2>/dev/null); then
	# Check if we are running tests
	if [ "$1" = "--test" ]; then
		# Run tests from the test file
		. "$HOME/dotfiles/bin/test/$(basename "${0##\-}")_test"
	else
		# If called directly, pass all arguments to the function
		$(basename "${0##\-}") "$@"
	fi
fi

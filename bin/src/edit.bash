#!/usr/bin/env bash

edit() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	if [ $# -eq 0 ]; then
		set -- "."
	fi
	# if the path is a directory, edit the directory without further checks
	if [ -d "$1" ]; then
		choose_editor "$1"
	# if the file is in the current directory, edit it
	elif [ -f "$1" ]; then
		choose_editor "$1"
	# if the file is a function, edit it by running it with EDIT=1 (which in my bash functions will fire up an editor at that line)
	elif contains "$(functions)" $1; then
		EDIT=1 $1
	# if the file is an executable, edit it
	elif contains "$(executables --scripts)" $1; then
		local full_path=$(which "$1")
		# search for presence of "unset EDIT" in file to assume it uses my pattern of firing up an editor for that file or function if EDIT is set and it is run
		if grep -q "unset EDIT" "$full_path"; then
			EDIT=1 "$1"
		else
			choose_editor "$full_path"
		fi
	else
		choose_editor "$1"
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

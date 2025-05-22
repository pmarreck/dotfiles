#!/usr/bin/env bash

append_dotfile_progress() {
		# Expand the abbreviated names
		local expanded_name
		case "$1" in
				"bp") expanded_name=".bash_profile" ;;
				"rc") expanded_name=".bashrc" ;;
				"env") expanded_name=".envconfig" ;;
				"P") expanded_name=".pathconfig" ;;
				"prof") expanded_name=".profile" ;;
				*) expanded_name="$1" ;;
		esac

		# Prevent duplicate entries
		if [[ ! $LAST_DOTFILE_RUN =~ ${expanded_name}-loaded\; ]]; then
				export LAST_DOTFILE_RUN="${LAST_DOTFILE_RUN:-}${expanded_name}-loaded;"
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

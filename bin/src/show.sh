#!/usr/bin/env bash

record_console_settings() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	__oldhistcontrol="$HISTCONTROL"
	__oldstate=$(set +o | sed 's/^/ /g')
}

restore_console_settings() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	# For some reason, this eval dumped all these set commands into HISTFILE/command history
	# so I used HISTCONTROL plus sed prefixing them with spaces (above) to prevent that
	eval "$__oldstate"
	export HISTCONTROL="$__oldhistcontrol"
	unset __oldhistcontrol
	unset __oldstate
}

record_console_settings
# The following 3 lines don't work when moved into the function above.
# Imperative languages suck.
	export HISTCONTROL=erasedups:ignoreboth
	set -o errexit -o pipefail -o noglob
	[[ "${DEBUG-0}" != "0" ]] && set -o xtrace

function var_defined {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	declare -p "$1" >/dev/null 2>&1
}

function func_defined {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	declare -F "$1" >/dev/null
}

function alias_defined {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	alias "$1" >/dev/null 2>&1
}

function defined {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	local word="$1"
	shift
	if [ -z "$word" ] && [ -z "$1" ]; then
		echo "Usage: defined <function or alias or variable or builtin or executable-in-PATH name> [...function|alias] ..."
		echo "Returns 0 if all the arguments are defined as a function or alias or variable or builtin or executable-in-PATH name."
		echo "This function is defined in ${BASH_SOURCE[0]}"
		return 0
	fi
	( "var_defined" "$word" || >/dev/null type -t "$word" ) && ( [ -z "$1" ] || "defined" "$@" )
}

function determine_language_from_source() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	local file="$1"
	if [ -f "$file" ]; then
		local file_ext=$(basename "$file" | cut -d. -f2-)
		local lang_orig=$(file "$file" | cut -d: -f2 | cut -d' ' -f2)
		local lang=${lang_orig,,}
		# add exceptions/overrides here
		case $lang in
			bourne-again*)
				lang_orig="Bash shell script"
				lang="bash"
				;;
			posix*)
				lang_orig="POSIX shell script"
				lang="sh"
				;;
			empty*)
				lang_orig="empty"
				lang="txt"
				;;
			ascii*)
				if [ "$file_ext" = "" ]; then
					lang_orig="ASCII text"
					lang="txt"
				elif [ "$file_ext" = "md" ]; then
					lang_orig="Markdown document"
					lang="md"
				else
					lang_orig="ASCII text, with extension '$file_ext'"
					lang="$file_ext"
				fi
				;;
			*)
				;;
		esac
		note "file '$file' is $(a_or_an "$lang_orig") $lang_orig file"
		echo "$lang"
		return 0
	else
		err "file '$file' does not exist"
		return 1
	fi
}

function a_or_an() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	local word="$1"
	shift
	if [ -z "$word" ]; then
		err "Usage: a_or_an <word>"
		return 1
	fi
	word=${word,,}
	case $word in
		# this was a surprising special case... "a md" sounds weird because we pronounce "md" as "em-dee" implying "an em-dee", not "a em-dee"
		# A general case would figure out if the word is pronounced as a literal spelling (like "md" = "em dee") and if so,
		# if the first letter's pronunciation begins with a vowel sound, but ain't nobody got time fo' dat for now
		md)
			echo "an"
			;;
		# "an unicode", "an unique", "an unicorn" sound weird, but "an unambiguous" doesn't. WTF?!?! How deep is this rabbit hole, English??
		uni*)
			echo "a"
			;;
		a*|e*|i*|o*|u*)
			echo "an"
			;;
		*)
			echo "a"
			;;
	esac
}

# "show": spit out the definition of any name
# usage: show <function or alias or variable or builtin or file or executable-in-PATH name> [...function|alias] ...
# It will dig out all definitions, helping you find things like overridden bins.
# Also useful to do things like exporting specific definitions to sudo contexts etc.
# or seeing if one definition is masking another.
# needs pygmentize "see pygments.org" # for syntax highlighting
# export PYGMENTIZE_STYLE=monokai
show() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	# on macOS, you need gnu-sed from homebrew or equivalent, which is installed as "gsed"
	# I set PLATFORM elsewhere in my env config
	# [ "$PLATFORM" = "osx" ] && local -r sed="gsed" || local -r sed="sed"
	# screw homebrew, all in on nix now; this is always gnused; YMMV
	local batless=false
	needs bat "please install bat to view some file listings or function definitions with syntax highlighting; using less instead" || batless=true
	local bat_opts="${BAT_OPTS:-"--tabs 0"}" # I removed -P to enable pagination
	$batless || export BAT_STYLE=${BAT_STYLE:-"grid,snip"}
	local word="$1"
	local found_undefined=0
	shift
	if [ -z "$word" ] && [ -z "$1" ]; then
		echo "Usage: show <function or alias or variable or builtin or executable-in-PATH name> [...function|alias] ..."
		echo "Returns the value or definition or location of those name(s)."
		echo "This function is defined in ${BASH_SOURCE[0]}"
		return 0
	fi
	# if it's a file, syntax-colorize it with bat or less, or display it via sixels if it's an image
	if [ -f "$word" ]; then
		local file_ext=$(basename "$word" | cut -d. -f2-)
		# if it's an image file, display it
		if file "$word" | grep -q image; then
			echo "$word"
			note "'${word}' is an image file:"
			needs magick "please install imagemagick" && \
			magick "$word" -resize 100% -geometry +0+0 -compress none -type truecolor sixel:-
		else
			echo "$word"
			local lang=$(determine_language_from_source "$word")
			if [ -n "$lang" ]; then
				note "'${word}' is $(a_or_an "$lang") $lang file on disk:"
				if [ "$file_ext" = "md" ] && needs glow "please install glow"; then
					glow "$word"
				else
					$batless && less "$word" || bat "$word" -l "$lang" $bat_opts 2>/dev/null
				fi
			else
				note "'${word}' is a file on disk, but it is not a text file"
			fi
		fi
	fi
	if var_defined "$word"; then
		local traits=()
		local decl=$(declare -p "$word" 2>/dev/null)
		local flags=${decl#declare\ -}
		local a_or_an="a"
		flags=${flags%% *}
		# Check if it's local (by seeing if declare -p outside function fails)
		( unset __local_check; local __local_check=42; declare -p __local_check 2>/dev/null ) >/dev/null && \
		declare -F &>/dev/null && caller >/dev/null && \
		[[ $(declare -p "$word" 2>/dev/null) =~ local\  ]] && traits+=("local")
		[[ $flags == *x* ]] && traits+=("exported")
		[[ $flags == *r* ]] && traits+=("readonly")
		[[ $flags == *i* ]] && traits+=("integer")
		[[ $flags == *a* ]] && traits+=("indexed array")
		[[ $flags == *A* ]] && traits+=("associative array")
		[[ $flags == *n* ]] && traits+=("nameref")
		[[ $flags == *-* ]] && traits+=("scalar")

		# Check if it's in env
		if env | grep --color=never -q "^$word=" &>/dev/null; then
			traits+=("environment")
		fi

		# get the output of declare -p
		declare_str=$(declare -p "$word" 2>/dev/null)
		if [[ $declare_str == declare\ --* ]]; then
			# replace leading "declare -- " with nothing
			declare_str=${declare_str#declare\ --\ }
		elif [[ $declare_str == declare\ -x* ]]; then
			# replace leading "declare -x" with "export"
			declare_str="export ${declare_str#declare\ -x\ }"
		fi
		# change a_or_an to "an" if the first letter of the first value in traits is a vowel. DETAILS, BABY!
		note "'${word}' is $(a_or_an "${traits[0]}") ${traits[*]} variable"
		echo "$declare_str"
	fi
	if ! [ -f "$word" ] && [ -z "$(type -a -t "$word")" ]; then
		warn "'${word}' is undefined"
		found_undefined=1
	else
		# if there are multiple types to search for, loop through them
		for type in $(type -a -t "$word" | uniq); do
			case $type in
				alias)
					note "'${word}' is an alias"
					alias "$word"
					;;
				function)
					note "'${word}' is a Bash function"
					# replace runs of 2 spaces with 1 space
					# and format the function definition the way I like it
					# It also needs bat, optionally
					local catter=less
					$batless || catter="bat -l bash $bat_opts"
					declare -f "$word" |\
						sed -z 's/\n{/ {/' |\
						sed 's/  / /g' |\
						sed -E 's/^([_[:alpha:]][_[:alnum:]]*)\s\(\)/\1()/' |\
						$catter
					;;
				builtin)
					note "'${word}' is a builtin"
					;;
				file)
					# if it's a file, just print the path
					note "'${word}' is at least one executable file in PATH"
					type -a -p "$word" | uniq | while read -r file; do
						echo "$file"
						if is_script "$file"; then
							local lang=$(determine_language_from_source "$file")
							$batless && less "$file" || bat -l "$lang" $bat_opts "$file"
						else
							note "($file is a binary, so we cannot view it)"
						fi
					done
					;;
				*)
					# things should not get here; if they do, add a case for them above
					note "'${word}' is not a variable, builtin, function, alias, or file; it is a $type"
					;;
			esac
		done
	fi
	# if there are any words left to look up, recurse with them.
	# Note that any undefined term will return 1 and stop evaluating the rest.
	[ -z "$1" ] || show "$@"
	# (return the sum of any non-zero exit codes)
	return $(( $found_undefined + $? ))
}

# this overrides /usr/bin/what, which I will likely never use anyway
what() {
	if [ "$1" == "is" ]; then # just to make it nicer to use
		shift
		show "$@"
	else
		show "$@"
	fi
}

restore_console_settings

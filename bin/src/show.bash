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

function determine_language_from_source() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	local file="$1"
	if [ -f "$file" ]; then
		# Check shebang first for accurate Lua/LuaJIT detection
		local shebang=$(head -1 "$file" 2>/dev/null)
		if [[ "$shebang" =~ ^#!/.*lua(jit)?$ ]] || [[ "$shebang" =~ ^#!/usr/bin/env[[:space:]]+(lua|luajit)$ ]]; then
			note "file '$file' is a Lua/LuaJIT script (detected from shebang)"
			echo "lua"
			return 0
		fi
		if [[ "$shebang" =~ ^#!/.*node(js)?$ ]] || [[ "$shebang" =~ ^#!/usr/bin/env[[:space:]]+node(js)?$ ]]; then
			note "file '$file' is a Node.js script (detected from shebang)"
			echo "js"
			return 0
		fi
		
		local filename=$(basename "$file")
		local file_ext=""
		if [[ "$filename" == *.* ]]; then
			file_ext=${filename#*.}
		fi
		debug "file_ext: '$file_ext'"
		# handle answers from file like "/nix/store/9gj9d5acy05q70z6gqfz834qz1vqvjbi-p7zip-17.06/bin/7z: a /nix/store/xhcgnphdwfg81j79nhspm0876cxglyj3-bash-5.2p37/bin/sh script text executable" properly
		local file_cmd_output=$(file -b "$file")
		debug "file_cmd_output: '$file_cmd_output'"
		# trim any leading "a " or "an "
		file_cmd_output=$(echo "$file_cmd_output" | sed 's/^a //g' | sed 's/^an //g')
		debug "file_cmd_output after sed: '$file_cmd_output'"
		# if the file_cmd_output starts with "/" (i.e., is a path), convert it to a basename
		if [[ "$file_cmd_output" == "/"* ]]; then
			debug "file_cmd_output starts with a path that is probably a hashbang executable"
			local file_path=$(echo "$file_cmd_output" | cut -d' ' -f1)
			debug "file_path: '$file_path'"
			file_path=$(basename "$file_path")
			debug "file_path after basename: '$file_path'"
			local file_details=$(echo "$file_cmd_output" | cut -d' ' -f2-)
			debug "file_details: '$file_details'"
			file_cmd_output="$file_path $file_details"
		fi
		debug "file_cmd_output after path: '$file_cmd_output'"
		local lang_orig=$(echo "$file_cmd_output" | cut -d' ' -f1)
		local lang=${lang_orig,,}
		
		# Handle JavaScript misidentification - check for Lua patterns
		if [[ "$lang" == "javascript" ]]; then
			# Check for common Lua patterns
			if grep -q "^local\|^require\|^ffi\.cdef\|^bit\." "$file" 2>/dev/null; then
				note "file '$file' is a Lua script (detected from content patterns)"
				echo "lua"
				return 0
			fi
		fi
		
		lang=$(truncate_run "$lang")
		debug "lang after truncate_run: '$lang'"
		if [ "$file_ext" = "wat" ]; then
			lang_orig="WebAssembly text (WAT)"
			lang="wat"
		fi
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
			lua*)
				lang_orig="Lua script"
				lang="lua"
				;;
			javascript*)
				lang_orig="JavaScript"
				lang="js"
				;;
			node.js*|nodejs*|node*)
				lang_orig="Node.js script"
				lang="js"
				;;
			yue)
				lang_orig="YueScript"
				lang="lua" # bat doesn't have a yuescript syntax parser yet
				;;
			moon)
				lang_orig="MoonScript"
				lang="lua" # bat doesn't have a moonscript syntax parser yet
				;;
			wasm)
				if [ "$lang" = "wat" ]; then
					# already reclassified above based on extension
					:
				elif [[ "$file_cmd_output" =~ [Tt]ext ]]; then
					lang_orig="WebAssembly text (WAT)"
					lang="wat"
				else
					lang_orig="WebAssembly binary"
					lang="wasm"
				fi
				;;
			wat)
				lang_orig=${lang_orig:-"WebAssembly text (WAT)"}
				lang="wat"
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
			symbolic*)
				lang_orig="symbolic link"
				lang="link"
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

# I have hashbang "runners" called yuerun and moonrun;
# when the file type detection encounters yuerun or moonrun (a *run suffix),
# it should truncate the "run" and return the result
function truncate_run() {
	local filename=$(basename "$1")
	if [[ "$filename" == *run ]]; then
		filename=${filename%run}
	fi
	echo "$filename"
}

map_highlight_language() {
	local lang="$1"
	case "$lang" in
		wat)
			echo "lisp"
			;;
		node.js|nodejs|node)
			echo "js"
			;;
		*)
			echo "$lang"
			;;
	esac
}

# Function to detect if a string is an HTTP(S) URL suitable for reader view
is_web_url() {
	local input="$1"
	# Check for HTTP/HTTPS URLs only (reader view is for web content)
	if [[ "$input" =~ ^https?://[^[:space:]]+$ ]]; then
		return 0
	fi
	# Check for www. domains (assume HTTPS)
	if [[ "$input" =~ ^www\.[^[:space:]]+\.[a-zA-Z]{2,}([/:].*)?$ ]]; then
		return 0
	fi
	# Check for domain.tld patterns (assume HTTPS for basic domains)
	if [[ "$input" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}([/:].*)?$ ]] && [[ ! "$input" =~ \.\.|\.$ ]]; then
		return 0
	fi
	return 1
}

# Help function for show command
show_help() {
	cat <<'EOF' | trim_leading_heredoc_whitespace
		show - Display definitions, values, and content of various items

		USAGE:
			show [--help|-h] [--browser|-b <browser>] <item> [item2] [item3] ...
			what [is] <item> [item2] [item3] ...

		BROWSER OPTIONS:
			reader: Uses 'reader -o url | glow' for fast markdown rendering
			clx-reader: Uses clx (circumflex) terminal reader mode
			links: Uses Links text-mode browser
			browsh: Uses Browsh (headless Firefox) browser

		DESCRIPTION:
			The 'show' command is a versatile tool that can display information about:
			- Bash functions, aliases, variables, and builtins
			- Files and executables in PATH
			- URLs (opens in terminal reader using clx)
			- Images (displays using sixel graphics if supported)

		SUPPORTED ITEM TYPES:

			Variables:
				Shows variable type, scope, and value with proper formatting.
				Detects: local, exported, readonly, integer, arrays, namerefs, environment variables.
				Example: show PATH

			Functions:
				Displays formatted function definition with syntax highlighting.
				Example: show show

			Aliases:
				Shows alias definition.
				Example: show ll

			Builtins:
				Identifies bash builtin commands.
				Example: show cd

			Files:
				- Text files: Syntax-highlighted display using bat (or less as fallback)
				- Images: Displays using sixel graphics via ImageMagick
				- Markdown: Rendered display using glow (if available)
				- Detects file type and language automatically
				Example: show ~/.bashrc

			Executables in PATH:
				Shows location and content of executable files.
				Follows symbolic links and displays target content.
				Example: show git

			URLs:
				Opens web URLs in terminal browser mode.
				Supports: http(s) protocols only (reader view is for web content)
				Also detects www.domain.com and domain.com patterns (assumes HTTPS)
				Browser options: reader (reader+glow), clx-reader (clx), links, browsh
				Example: show https://example.com

		FEATURES:
			- Multiple items: Can process multiple items in one command
			- Type detection: Automatically determines the best way to display each item
			- Syntax highlighting: Uses bat for code/text files with language detection
			- Image support: Displays images directly in terminal using sixel graphics
			- Link following: Resolves symbolic links and shows target content
			- Error handling: Graceful fallbacks when optional tools are unavailable

		DEPENDENCIES:
			Required: bash, file, readlink
			Optional: bat (syntax highlighting), glow (markdown), magick (images)
			URL browsers: reader+glow (fast), clx (clx-reader mode), links, browsh

		ENVIRONMENT VARIABLES:
			TUI_BROWSER: Default browser for URLs (reader|clx-reader|links|browsh, default: clx-reader)
			BAT_OPTS: Options passed to bat (default: "--tabs 0")
			BAT_STYLE: Bat style setting (default: "grid,snip")
			PYGMENTIZE_STYLE: Syntax highlighting style (e.g., "monokai")

		EXAMPLES:
			show ls                    # Show ls command location and content
			show ~/.vimrc             # Display vimrc with syntax highlighting
			show PATH HOME            # Show multiple variables
			show https://github.com   # Open URL in default browser (clx-reader)
			show -b reader https://github.com  # Open URL with reader+glow (fast)
			show -b links https://github.com  # Open URL in Links browser
			show --browser browsh https://github.com  # Open URL in Browsh
			show image.png            # Display image in terminal
			show --help               # Show this help message

		ALIASES:
			what [is] <item>          # Alternative command name

		EXIT STATUS:
			0: All items found and displayed successfully
			1: One or more items were undefined or inaccessible

		This function is defined in: $HOME/dotfiles/bin/src/show.bash
EOF
}

# "show": spit out the definition of any name
# usage: show <function or alias or variable or builtin or file or executable-in-PATH name or URL> [...function|alias] ...
# It will dig out all definitions, helping you find things like overridden bins.
# Also useful to do things like exporting specific definitions to sudo contexts etc.
# or seeing if one definition is masking another.
# For URLs, it will open them in a terminal reader view using clx (circumflex).
# needs pygmentize "see pygments.org" # for syntax highlighting
# export PYGMENTIZE_STYLE=monokai
show() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	
	# Parse arguments for browser selection
	local browser="${TUI_BROWSER:-clx-reader}"  # Default to clx-reader, can be overridden by env var
	local args=()
	
	while [[ $# -gt 0 ]]; do
		case $1 in
			--help|-h)
				show_help
				return 0
				;;
			--browser|-b)
				if [[ -n "$2" && "$2" != -* ]]; then
					browser="$2"
					shift 2
				else
					err "--browser/-b requires an argument (reader|clx-reader|links|browsh)"
					return 1
				fi
				;;
			*)
				args+=("$1")
				shift
				;;
		esac
	done
	
	# Validate browser option
	case "$browser" in
		reader|clx-reader|links|browsh)
			# Valid options
			;;
		*)
			err "Invalid browser option: '$browser'. Valid options are: reader, clx-reader, links, browsh"
			return 1
			;;
	esac
	
	# Restore positional parameters
	set -- "${args[@]}"
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
		echo "Usage: show <function or alias or variable or builtin or executable-in-PATH name or URL> [...function|alias] ..."
		echo "Returns the value or definition or location of those name(s), or opens URLs in terminal reader."
		echo "Use 'show --help' for detailed usage information."
		echo "This function is defined in ${BASH_SOURCE[0]}"
		return 0
	fi
	# if it's a web URL, open it with selected browser
	if is_web_url "$word"; then
		echo "$word"
		# All browsers need explicit protocol, add https:// if missing
		local full_url="$word"
		if [[ ! "$full_url" =~ ^https?:// ]]; then
			full_url="https://$full_url"
		fi
		case "$browser" in
			reader)
				note "'${word}' is a web URL, opening with reader + glow:"
				if needs reader "please install reader to fetch web URLs" && needs glow "please install glow to render markdown"; then
					reader -o "$full_url" | glow
				else
					err "reader and glow are required to view web URLs but one or both are not available in PATH"
					return 1
				fi
				;;
			clx-reader)
				note "'${word}' is a web URL, opening in clx terminal reader:"
				if needs clx "please install clx (circumflex) to view web URLs in terminal reader mode"; then
					clx url "$full_url"
				else
					err "clx (circumflex) is required to view web URLs but is not available in PATH"
					return 1
				fi
				;;
			links)
				note "'${word}' is a web URL, opening in Links browser:"
				if needs links "please install links to view web URLs in Links browser"; then
					links "$full_url"
				else
					err "links is required to view web URLs but is not available in PATH"
					return 1
				fi
				;;
			browsh)
				note "'${word}' is a web URL, opening in Browsh browser:"
				if needs browsh "please install browsh to view web URLs in Browsh browser"; then
					browsh "$full_url"
				else
					err "browsh is required to view web URLs but is not available in PATH"
					return 1
				fi
				;;
		esac
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
				local highlight_lang=$(map_highlight_language "$lang")
				note "'${word}' is $(a_or_an "$lang") $lang file on disk:"
				if [ "$file_ext" = "md" ] && needs glow "please install glow"; then
					glow "$word"
				else
					$batless && less "$word" || bat "$word" -l "$highlight_lang" $bat_opts 2>/dev/null
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
	# Only check for types if it's not a file (files are already handled above)
	if ! [ -f "$word" ]; then
		local types_found=$(type -a -t "$word" | uniq)
		if [ -z "$types_found" ]; then
			# Not a file, not a type, check if it was already found as a variable
			if ! var_defined "$word"; then
				warn "'${word}' is undefined"
				found_undefined=1
			fi
		else
			# if there are multiple types to search for, loop through them
			for type in $types_found; do
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
							local highlight_lang=$(map_highlight_language "$lang")
							case $lang in
								link)
									local link_target=$(readlink -f "$file")
									note "'${file}' is a symbolic link to '$link_target'"
									# cut the last 3 space delimited fields:
									# follow the link:
									debug "source link: $file"
									file=$link_target
									debug "resolved link: $file"
									lang=$(determine_language_from_source "$file")
									highlight_lang=$(map_highlight_language "$lang")
									debug "language: $lang"
									;;&    # yes, this is a Bash 4 thing that falls through to the next case
								*)
									$batless && less "$file" || bat -l "$highlight_lang" $bat_opts "$file"
									;;
							esac
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
	fi
	# if there are any words left to look up, recurse with them.
	# Note that any undefined term will return 1 and stop evaluating the rest.
	[ -z "$1" ] || show "$@"
	# (return the sum of any non-zero exit codes)
	return $(( $found_undefined + $? ))
}

# this overrides /usr/bin/what, which I will likely never use anyway
# Usage: what [is] <name of anything> (redirects to show function)
what() {
	if [ "$1" == "is" ]; then # just to make it nicer to use
		shift
		show "$@"
	else
		show "$@"
	fi
}

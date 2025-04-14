source_relative_once truthy.bash

# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
>/dev/null declare -F needs || \
needs() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin=$1
  shift
  command -v "$bin" >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}
export -f needs

# check if the AWK environment variable is already set and if not, set it to frawk, gawk, or awk
[ -z "${AWK}" ] && export AWK=$(command -v frawk || command -v gawk || command -v awk)

if truthy RUN_DOTFILE_TESTS; then
  source_relative_once assert.bash
  source_relative_once test_reporter.bash
fi

save_shellenv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  export OLDHISTIGNORE=$HISTIGNORE
  export HISTIGNORE="shopt:set:eval"
  _prev_shell_opts=$(set +o; shopt -p;)
}
export -f save_shellenv

restore_shellenv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  eval "$_prev_shell_opts"
  # clean up after ourselves, don't want to pollute the ENV
  unset _prev_shell_opts
  export HISTIGNORE=$OLDHISTIGNORE
  unset OLDHISTIGNORE
}
export -f restore_shellenv

uniquify_array() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # ${AWK:-awk} '!seen[$0]++'
  # declare -n arr=$1  # indirect reference to the array name passed in as arg1
  # edit: forcing compatibility with bash < 4.2 (which doesn't support declare -n)
  # We can't use nameref, so use eval to indirectly reference the array
  eval 'arr=("${'"$1"'[@]}")'
  declare -A seen
  local unique_arr=()
  # Iterate over array elements, space-separated
  for value in "${arr[@]}"; do
    # Check if the value has been seen before
    if [[ -z "${seen[$value]}" ]]; then
      seen["$value"]=1
      unique_arr+=("$value")
    fi
  done
  # Assign unique values back to the original array using eval (grrr)
  eval "$1=(\"\${unique_arr[@]}\")"
}
export -f uniquify_array

array_contains_element() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # declare -n array=$1
  # We can't use nameref, so use eval to indirectly reference the array
  eval 'array=("${'"$1"'[@]}")'
  element="$2"

  # Loop through the array and check if the element exists
  for item in "${array[@]}"; do
    if [[ "$item" == "$element" ]]; then
      # Element found in array, exit with 0
      return 0
    fi
  done

  # If we got here, the element was not found in the array, exit with 1
  return 1
}
export -f array_contains_element

move_PROMPT_COMMAND_to_precmd_functions() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # Replace newlines with semicolons
  PROMPT_COMMAND=${PROMPT_COMMAND//$'\n'/;}

  # Replace runs of 2 or more semicolons with one
  while [[ $PROMPT_COMMAND == *';;'* ]]; do
    PROMPT_COMMAND=${PROMPT_COMMAND//;;/;}
  done

  # Remove trailing semicolons
  PROMPT_COMMAND=${PROMPT_COMMAND%;}

  # Then split on semicolons
  IFS=';' read -ra commands <<< "$PROMPT_COMMAND"
  for cmd in "${commands[@]}"; do
    precmd_functions+=("$cmd")
  done

  # Then clear PROMPT_COMMAND
  PROMPT_COMMAND=''
}
export -f move_PROMPT_COMMAND_to_precmd_functions

# Minimalist rehash function for shell refreshing
function rehash() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  
  # Skip all tests and hooks during rehash
  export SKIP_DOTFILE_TESTS=true
  export TEST_VERBOSE=false
  export EXPAND_TEST_VERBOSE=false
  
  # Save current environment settings
  local OLD_LAST_DOTFILE_RUN="${LAST_DOTFILE_RUN:-}"
  
  # Clear source tracking
  unset _SOURCED_FILES
  
  # Source only the essential files
  if [[ -f "$HOME/dotfiles/bin/aliases.sh" ]]; then
    source "$HOME/dotfiles/bin/aliases.sh"
  fi
  
  if [[ -f "$HOME/dotfiles/.pathconfig" ]]; then
    source "$HOME/dotfiles/.pathconfig"
  fi
  
  if [[ -f "$HOME/dotfiles/.envconfig" ]]; then
    source "$HOME/dotfiles/.envconfig"
  fi
  
  # Restore saved variables
  export LAST_DOTFILE_RUN="${OLD_LAST_DOTFILE_RUN}"
  
  # Clean up
  unset SKIP_DOTFILE_TESTS
  
  # Inform user
  echo "Shell environment refreshed without running tests."
}
export -f rehash

# This function emits an OSC 7 sequence to inform the terminal
# of the current working directory.  It prefers to use a helper
# command provided by wezterm if wezterm is installed, but falls
# back to a simple printf command otherwise.
__wezterm_osc7() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local default_directory=${1:-$PWD}
  if hash wezterm 2>/dev/null ; then
    wezterm set-working-directory $default_directory 2>/dev/null && return 0
    # If the command failed (perhaps the installed wezterm
    # is too old?) then fall back to the simple version below.
  fi
  printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "${default_directory}"
}
export -f __wezterm_osc7

__wezterm_osc7_home() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  __wezterm_osc7 "$HOME"
}
export -f __wezterm_osc7_home

trim_leading_heredoc_whitespace() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  #  echo "Debug: Function started" >&2
  # For some reason, frawk screws this up. No time to troubleshoot.
  needs gawk "please install gawk (GNU awk) to run this function" && \
  gawk '
  BEGIN { shortest = -1 }
  {
    lines[NR] = $0
    #  print "Debug: Processing line: [" $0 "]" > "/dev/stderr"
    #  print "Debug: Line length: " length($0) > "/dev/stderr"
    match($0, /[^[:space:]]/);
    #  print "Debug: RSTART = " RSTART > "/dev/stderr"
    if (RSTART > 0) {
      if (shortest == -1 || RSTART - 1 < shortest) {
        shortest = RSTART - 1
      #  print "Debug: shortest updated to " shortest > "/dev/stderr"
    }
  } else {
    #  print "Debug: No match found in this line" > "/dev/stderr"
  }
}
END {
  #  print "Debug: END block reached, shortest = " shortest > "/dev/stderr"
    if (shortest >= 0) {
      for (i=1; i<=NR; i++) {
        if (length(lines[i]) > shortest) {
          print substr(lines[i], shortest + 1)
        } else {
          print ""
        }
      }
    } else {
    #  print "Debug: No processing done (shortest < 0)" > "/dev/stderr"
  }
}
'
#  echo "Debug: Function ended" >&2
}
export -f trim_leading_heredoc_whitespace

if truthy RUN_DOTFILE_TESTS; then
  test_trim_leading_heredoc() {
    assert "$(echo -e "  This\n  is a\n    multiline\n  string." | trim_leading_heredoc_whitespace)" == "This\nis a\n  multiline\nstring."
  }
  run_test_suite "trim_leading_heredoc" : test_trim_leading_heredoc :
fi

unwrap() {
  local SED=`which sed`
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # this expects contents to be piped in via stdin
  [[ "$(sed --version | head -1)" =~ .*GNU.* ]] || echo "WARNING: function unwrap: The sed on PATH is not GNU sed, which may cause problems" >&2 && SED="/run/current-system/sw/bin/sed"
  # sed -E -e ':a;N;$!ba' -e 's/( \n | \n|\n )/ /g'
  $SED -E ':a;N;$!ba;s/( +\n +| *\n +| +\n *)/ /g'
}
export -f unwrap

if truthy RUN_DOTFILE_TESTS; then
  test_unwrap_wrap() {
    # test unwrap
    assert "$(echo -e "This\nis a \nmultiline\n string." | unwrap)" == "This\nis a multiline string."
    # test unwrap preserving double newlines
    assert "$(echo -e "This\nis a\n\nmultiline\n string." | unwrap)" == "This\nis a\n\nmultiline string."
    # test wrap
    assert "$(echo -e "This is a long line that should be wrapped to width 16." | wrap 16)" == "This is a long \nline that \nshould be \nwrapped to \nwidth 16."
  }
  run_test_suite "unwrap_wrap" : test_unwrap_wrap :
fi

wrap() {
  # take an argument of colwidth but default to current terminal width
  local colwidth=${1:-$(tput cols)}
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # this expects contents to be piped in via stdin
  fold -s -w $colwidth
}
export -f wrap

isacolortty() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  [[ "$TERM" =~ 'color' ]] && return 0 || return 1
}
export -f isacolortty

if truthy RUN_DOTFILE_TESTS; then
  test_isacolortty() {
    TERM=xterm-256color isacolortty
    assert "$?" == "0"
    TERM=dumb isacolortty
    assert "$?" == "1"
  }
  run_test_suite "isacolortty" : test_isacolortty :
fi

strip_ansi() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local ansiregex="s/\x1b\[[0-9;]*[a-zA-Z]//g"

  if [ -t 0 ] && [ "$#" -eq 0 ]; then
    printf "Usage: strip_ansi [text]\n"
    printf "   or: printf '%%s' text | strip_ansi\n"
    return 1
  fi

  if [ -t 0 ]; then
    # Input from arguments
    printf '%b' "$*" | $SED -E "$ansiregex"
  else
    # Input from pipe
    $SED -E "$ansiregex"
  fi
}
export -f strip_ansi

if truthy RUN_DOTFILE_TESTS; then
  test_strip_ansi() {
    # Test with printf-generated ANSI sequences
    assert "$(printf '\e[31mRed text\e[0m' | strip_ansi)" == "Red text"
    # Test with literal ANSI sequences
    assert "$(echo -e '\e[93mYellow text\e[0m' | strip_ansi)" == "Yellow text"
    # Test with complex ANSI sequences
    assert "$(printf '\e[1;31;42mBold red on green\e[0m' | strip_ansi)" == "Bold red on green"
  }
  run_test_suite "strip_ansi" : test_strip_ansi :
fi

elixir_js_loc() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  git ls-files | grep -E '\.erl|\.exs?|\.js$' | xargs cat | $SED -e '/^$/d' -e '/^ *#/d' -e '/^ *\/\//d' | wc -l
}
export -f elixir_js_loc

open_gem() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  choose_editor "$(bundle show "$1")"
}
export -f open_gem

contains() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  [[ "$2" == "" ]] && return 0 # Empty string is contained in every string (including empty string)
  local word
  for word in $1; do
    if [[ "$word" == "$2" ]]; then
      return 0
    fi
  done
  return 1
}
export -f contains

if truthy RUN_DOTFILE_TESTS; then
  test_contains() {
    contains "foo bar baz" "bar"
    assert "$?" == "0"
    contains "foo bar baz" "quux"
    assert "$?" == "1"
    # Empty string is contained in every string (including empty string)
    # This follows from the mathematical principle that ε is a substring of all strings
    contains "foo" ""
    assert "$?" == "0"
  }
  run_test_suite "contains" : test_contains :
fi

edit() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if contains "$(functions)" $1; then
    EDIT=1 $1
  else
    choose_editor "$@"
  fi
}
export -f edit

ltrim() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  printf '%s' "$var"
}
export -f ltrim

rtrim() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local var="$*"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}
export -f rtrim

trim() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local var="$*"
  var="$(ltrim "$var")"
  var="$(rtrim "$var")"
  printf '%s' "$var"
}
export -f trim

if truthy RUN_DOTFILE_TESTS; then
  test_trim() {
    assert "$(ltrim "  foo  ")" == "foo  "
    assert "$(rtrim "  foo  ")" == "  foo"
    assert "$(trim "  foo  ")" == "foo"
  }
  run_test_suite "trim" : test_trim :
fi

datetime() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  date "+%Y-%m-%d %H:%M:%S"
}
export -f datetime

datetime-human() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  date +"%A, %B %d, %Y %I:%M %p"
}
export -f datetime-human

image_convert_to_heif() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # base name of argument 1
  # local bn="${1%.*}"
  # ffmpeg -i "$1" -c:v libx265 -preset ultrafast -x265-params lossless=1 "${bn}.heif"

  # lossless conversion, FYI
  needs heif-enc "please install libheif" && \
  echo_eval "heif-enc -L -p chroma=444 --matrix_coefficients=0 \"$1\""
}
export -f image_convert_to_heif

image_convert_to_jpegxl() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # base name of argument 1
  local bn="${1%.*}"
  local d="${JXL_DISTANCE:-0}" # 0-9 where 0 is lossless; default 0
  local e="${JXL_EFFORT:-7}" # 0-9 where 9 is extremely slow but smallest; default 7

  needs cjxl "please install the libjxl package to get the cjxl executable" && \
  echo_eval "cjxl -d $d -e $e --lossless_jpeg=0 \"$1\" \"${bn}.jxl\""
}
export -f image_convert_to_jpegxl

# supertop: open htop and btop at the same time in a tmux split
# requires btop and htop to be installed
supertop() {
  if ! command -v tmux &> /dev/null; then
    err "tmux is not installed. Please install it first, along with btop and htop.";
    return 1;
  fi;

  local session_name;
  session_name="split_session_$$";

  # Create the tmux session
  tmux new-session -d -s "${session_name}" 'htop';
  tmux split-window -h 'btop';
  tmux attach-session -t "${session_name}";
}
export -f supertop

puts() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local print_fmt end_fmt print_spec fd newline
  print_fmt=''
  end_fmt=''
  print_spec='%s'
  newline='\n'
  fd='1'
  while true; do
    case "${1}" in
      (--help)
        cat << EOF
Usage: puts [OPTIONS] [TEXT]

A utility function for formatted text output.

Options:
  --help     Display this help message
  --green    Print text in green color
  --yellow   Print text in yellow color
  --orange   Print text in orange color
  --red      Print text in red color
  --stderr   Output to stderr instead of stdout
  -n         Do not append a newline
  -e         Interpret backslash escapes (like \\n, \\t)
  -en, -ne   Combine -e and -n options
  -E         Do not interpret backslash escapes (default)
EOF
        return 0
        ;;
      (--green)   print_fmt='\e[32m'; end_fmt='\e[0m' ;;
      (--yellow)  print_fmt='\e[93m'; end_fmt='\e[0m' ;;
      (--orange)  print_fmt='\e[38;5;208m'; end_fmt='\e[0m' ;;
      (--red)     print_fmt='\e[31m'; end_fmt='\e[0m' ;;
      (--stderr)  fd='2' ;;
      (-n)        newline='' ;;
      (-e)        print_spec='%b' ;;
      (-en|-ne)   print_spec='%b'; newline='' ;;
      (-E)        print_spec='%s' ;;
      (-*)        fail "Unknown format specifier: ${1}" ;;
      (*)         break ;;
    esac
    shift
  done

  # If we're not interactive/color, override print_fmt and end_fmt to remove ansi
  isacolortty || unset -v print_fmt end_fmt

  # shellcheck disable=SC2059
  printf -- "${print_fmt}${print_spec}${end_fmt}${newline}" "${*}" >&$fd
}
export -f puts

# ANSI color helpers
red_text() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  puts --red -en "$*"
}
export -f red_text

green_text() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  puts --green -en "$*"
}
export -f green_text

yellow_text() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  puts --yellow -en "$*"
}
export -f yellow_text

orange_text() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  puts --orange -en "$*"
}
export -f orange_text

echo_eval() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  yellow_text "$*\n" >&2
  eval "$*"
}
export -f echo_eval

# exit with red text to stderr, optional 2nd arg is error code
die() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  red_text "${1}" >&2
  echo >&2
  exit ${2:-1}
}
export -f die

# fail with red text to stderr, optional 2nd arg is return code
fail() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  red_text "${1}" >&2
  echo >&2
  return ${2:-1}
}
export -f fail

# mute stdout and stderr and only return the return code
success?() {
  "$@" >/dev/null 2>&1
  return $?
}
export -f success?
# mute stdout and stderr and only return the return code
error?() {
  ! success? "$@"
  return $?
}
export -f error?

remove_z_library_attrib() {
  local files
  # Use sed to convert unescaped spaces to newlines and remove backslashes in one pass
  IFS=$'\n' files=($(expand "*\ \(Z-Library\).*" | sed -e 's/\([^\\]\) /\1\n/g' -e 's/\\//g'))
  if [[ ${#files[@]} -eq 1 && "${files[0]}" == "*\ (Z-Library).*" ]]; then
    return  # No matches
  fi
  for file in "${files[@]}"; do
    mv "$file" "${file/ (Z-Library)/}"
  done
}
export -f remove_z_library_attrib

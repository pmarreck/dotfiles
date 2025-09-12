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

# check if the AWK environment variable is already set and if not, set it to frawk, gawk, or awk
[ -z "${AWK}" ] && export AWK=$(command -v frawk || command -v gawk || command -v awk)

save_shellenv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  export OLDHISTIGNORE=$HISTIGNORE
  export HISTIGNORE="shopt:set:eval"
  _prev_shell_opts=$(set +o; shopt -p;)
}

restore_shellenv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  eval "$_prev_shell_opts"
  # clean up after ourselves, don't want to pollute the ENV
  unset _prev_shell_opts
  export HISTIGNORE=$OLDHISTIGNORE
  unset OLDHISTIGNORE
}

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

# Minimalist rehash function for shell refreshing
function rehash() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  
  # Skip all tests and hooks during rehash
  export SKIP_DOTFILE_TESTS=true
  export TEST_VERBOSE=false
  export GLOB_TEST_VERBOSE=false
  
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

__wezterm_osc7_home() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  __wezterm_osc7 "$HOME"
}

if truthy RUN_DOTFILE_TESTS; then
  test_trim_leading_heredoc() {
    assert "$(echo -e "  This\n  is a\n    multiline\n  string." | trim_leading_heredoc_whitespace)" == "This\nis a\n  multiline\nstring."
  }
  run_test_suite "trim_leading_heredoc" : test_trim_leading_heredoc :fi


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



if truthy RUN_DOTFILE_TESTS; then
  test_isacolortty() {
    TERM=xterm-256color isacolortty
    assert "$?" == "0"
    TERM=dumb isacolortty
    assert "$?" == "1"
  }
  run_test_suite "isacolortty" : test_isacolortty :
fi


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

open_gem() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  choose_editor "$(bundle show "$1")"
}


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





if truthy RUN_DOTFILE_TESTS; then
  test_trim() {
    assert "$(ltrim "  foo  ")" == "foo  "
    assert "$(rtrim "  foo  ")" == "  foo"
    assert "$(trim "  foo  ")" == "foo"
  }
  run_test_suite "trim" : test_trim :
fi


datetime-human() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  date +"%A, %B %d, %Y %I:%M %p"
}



# supertop: open htop and btop at the same time in a tmux split
# requires btop and htop to be installed

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

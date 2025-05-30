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
  local word="$1"
  shift
  if [ -z "$word" ] && [ -z "$1" ]; then
    echo "Usage: show <function or alias or variable or builtin or executable-in-PATH name> [...function|alias] ..."
    echo "Returns the value or definition or location of those name(s)."
    echo "This function is defined in ${BASH_SOURCE[0]}"
    return 0
  fi
  # if it's a file, syntax-colorize it with bat or less, or display it via sixels if it's an image
  if [ -f "$word" ]; then
    # if it's an image file, display it
    if file "$word" | grep -q image; then
      note "$word is an image file"
      needs magick "please install imagemagick" && \
      magick "$word" -resize 100% -geometry +0+0 -compress none -type truecolor sixel:-
      return 0
    else
      note "$word is a file on disk"
      needs bat "please install bat" && \
      bat "$word" 2>/dev/null
      if [ $? -eq 0 ]; then
        return 0
      else
        less "$word"
      fi
    fi
  elif env | grep -q "^$word="; then
    local xported=""
    if [[ $(declare -p "$word" 2>/dev/null) == declare\ -x* ]]; then
      xported="exported "
    fi
    note "$word is an ${xported}environment variable"
    env | grep --color=never "^$word="
  elif var_defined "$word"; then
    # get the output of declare -p
    declare_str=$(declare -p "$word" 2>/dev/null)
    if [[ $declare_str == declare\ -a* ]]; then
      note "$word is an indexed array variable"
    elif [[ $declare_str == declare\ -A* ]]; then
      note "$word is an associative array variable"
    elif [[ $declare_str == declare\ --* ]]; then
      note "$word is a scalar variable"
    elif [[ $declare_str == declare\ -x* ]]; then
      note "$word is an exported variable"
    elif [[ $declare_str == declare\ -r* ]]; then
      note "$word is a readonly variable"
    elif [[ $declare_str == declare\ -i* ]]; then
      note "$word is an integer variable"
    else
      note "I have no idea what kind of variable $word is, but it is defined:"
    fi
    echo "$declare_str"
  elif [ -z "$(type -a -t "$word")" ]; then
    warn "$word is undefined"
    return 1
  else
    # if there are multiple types to search for, loop through them
    for type in $(type -a -t "$word" | uniq); do
      case $type in
        builtin)
          note "$word is a builtin"
          ;;
        function)
          note "$word is a function"
          # replace runs of 2 spaces with 1 space
          # and format the function definition the way I like it
          # It also needs bat, optionally
          local catter=less
          needs bat "please install bat to view function definitions with syntax highlighting" && catter="bat -l bash -P"
          declare -f "$word" |\
            sed -z 's/\n{/ {/' |\
            sed 's/  / /g' |\
            sed -E 's/^([_[:alpha:]][_[:alnum:]]*)\s\(\)/\1()/' |\
            $catter
          ;;
        alias)
          note "$word is an alias"
          alias "$word"
          ;;
        file)
          # if it's a file, just print the path
          note "$word is at least one executable file in PATH"
          type -a -p "$word" | uniq | while read -r file; do
            if is_script "$file"; then
              less "$file"
            else
              note "($file is not a script so we cannot view it)"
            fi
          done
          ;;
        *)
          # things should not get here; if they do, add a case for them above
          note "$word is not a variable, builtin, function, alias, or file; it is a $type"
          ;;
      esac
    done
  fi
  # if there are any words left to look up, recurse with them.
  # Note that any undefined term will return 1 and stop evaluating the rest.
  [ -z "$1" ] || show "$@"
}

restore_console_settings

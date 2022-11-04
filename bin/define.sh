#!/usr/bin/env bash
__oldstate=$(set +o)
set -o errexit -o nounset -o pipefail
if [[ "${DEBUG-0}" != "0" ]]; then set -o xtrace; fi

# alerting in yellow to stderr
$(declare -F note >/dev/null) || note() {
  >&2 printf "\e[0;33m%s\e[0;39m\n" "$@"
}
# warning in red to stderr
$(declare -F warn >/dev/null) || warn() {
  >&2 printf "\e[0;31m%s\e[0;39m\n" "$@"
}

function var_defined? {
  declare -p "$1" >/dev/null 2>&1
}

function func_defined? {
  declare -F "$1" >/dev/null
}

function defined? {
  local word="$1"
  shift
  if [ -z "$word" ] && [ -z "$1" ]; then
    echo "Usage: defined? <function or alias or variable or builtin or executable-in-PATH name> [...function|alias] ..."
    echo "Returns 0 if all the arguments are defined as a function or alias or variable or builtin or executable-in-PATH name."
    echo "This function is defined in $BASH_SOURCE"
    return 0
  fi
  ( var_defined? "$word" || >/dev/null type -t "$word" ) && ( [ -z "$1" ] || defined? "$@" )
}

# "define": spit out the definition of any name
# usage: define <function or alias or variable or builtin or executable-in-PATH name> [...function|alias] ...
# It will dig out all definitions, helping you find things like overridden bins.
# Also useful to do things like exporting specific definitions to sudo contexts etc.
# or seeing if one definition is masking another.
define() {
  local word="$1"
  shift
  if [ -z "$word" ] && [ -z "$1" ]; then
    echo "Usage: define <function or alias or variable or builtin or executable-in-PATH name> [...function|alias] ..."
    echo "Returns the value or definition or location of those name(s)."
    echo "This function is defined in $BASH_SOURCE"
    return 0
  fi
  if $(env | grep -q "^$word="); then
    note "$word is an environment variable"
    env | grep --color=never "^$word="
  elif [ -z "$(type -a -t $word)" ]; then
    warn "$word is undefined"
  else
    # if there are multiple types to search for, loop through them
    for type in $(type -a -t $word | uniq); do
      case $type in
        builtin)
          note "$word is a builtin"
          ;;
        function)
          note "$word is a function"
          # replace runs of 2 spaces with 1 space
          # and format the function definition the way I like it
          declare -f $word |\
            sed -z 's/\n{/ {/' |\
            sed 's/  / /g' |\
            sed -E 's/^([_[:alpha:]][_[:alnum:]]*)\s\(\)/\1()/'
          ;;
        alias)
          note "$word is an alias"
          alias $word
          ;;
        file)
          # if it's a file, just print the path
          note "$word is at least one executable file in PATH"
          type -a -p $word | uniq
          ;;
        *)
          # things should not get here; if they do, add a case for them above
          note "$word is not a variable, builtin, function, alias, or file; it is a $type"
          # return 1
          ;;
      esac
    done
  fi
  # if there are any words left to look up, recurse with them
  if [ ! -z "$1" ]; then
    define $@
  fi
}
eval "$__oldstate"
unset __oldstate

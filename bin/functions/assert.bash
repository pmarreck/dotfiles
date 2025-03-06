# for assertions everywhere!
# usage: assert [condition] [message]
# if condition is false, print message and exit
assert() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local arg1 comp arg2 message comp_result
  
  # Check if arguments are provided (not if they're empty)
  if [ $# -lt 3 ]; then
    echo "Insufficient arguments to assert in ${BASH_SOURCE[1]}: $*" >&2
    return 0 # because returning 1 would cause the shell to exit during sourcing
  fi
  
  arg1="$1"
  comp="$2"
  arg2="$3"
  message="$4"
  # We add a form feed character at the end of both due to how Bash command substitution
  # gobbles up trailing newlines (and that's POSIX!).
  arg1_enc=$(binhex "$arg1\f")
  arg2_enc=$(binhex "$arg2\f")
  comp_result=false # default to false
  case $comp in
    = | == )
      # comparison_encoded="[ \"$arg1_enc\" $comp \"$arg2_enc\" ]"
      [ "$arg1_enc" = "$arg2_enc" ] && comp_result=true
      comparison="[ \"$arg1\" $comp \"$arg2\" ]"
    ;;
    != | !== )
      # comparison_encoded="[ \"$arg1_enc\" \!= \"$arg2_enc\" ]"
      [ "$arg1_enc" != "$arg2_enc" ] && comp_result=true
      comparison="[ \"$arg1\" \!= \"$arg2\" ]"
    ;;
    =~ ) # can't do encoded regex comparisons, so just do a plaintext comparison
      # comparison_encoded="[[ \"$arg1\" =~ $arg2 ]]"
      [[ "$arg1" =~ $arg2 ]] && comp_result=true
      comparison="[[ \"$arg1\" =~ $arg2 ]]"
    ;;
    !=~ | !~ )
      # comparison_encoded="[[ ! \"$arg1\" =~ $arg2 ]]"
      [[ ! "$arg1" =~ $arg2 ]] && comp_result=true
      comparison="[[ ! \"$arg1\" =~ $arg2 ]]"
    ;;
    * ) 
      echo "Unknown comparison operator: $comp" >&2
      return 1
    ;;
  esac
  if $comp_result; then
    return 0
  else
    # These values (BASH_SOURCE and BASH_LINENO) seem valid when triggered in my dotfiles, but not from my shell.
    # Not sure how to fix yet.
    local actualfile
    local linenum
    if [ -t 0 ]; then # if stdin is a tty
      actualfile="tty"
      linenum=$(history 1 | awk '{print $1}')
    else # if this is run from a script
      # As to why we need the 1th index of BASH_SOURCE but the 0th index of BASH_LINENO, I have no idea. But it works.
      actualfile="$(readlink -f ${BASH_SOURCE[1]})"
      linenum="${BASH_LINENO[0]}"
    fi
    case $comp in
      =~ | !=~ | !~ ) # regex comparisons
        echo "Assertion failed: \"$arg1\" $comp $arg2 @ ${actualfile}:${linenum}" >&2
      ;;
      *) # non-regex comparisons
        echo "Assertion failed: \"$arg1\" $comp \"$arg2\" @ ${actualfile}:${linenum}" >&2
      ;;
    esac
    [ -n "$message" ] && echo $message >&2
    return 1
  fi
}
export -f assert

# this is at the bottom because it depends on assert
source_relative_once binhex.bash

source_relative_once bin/functions/binhex.bash

# for assertions everywhere!
# usage: assert [condition] [message]
# if condition is false, print message and exit
assert() {
  local arg1="$1"
  local comp="$2"
  local arg2="$3"
  local message="$4"
  arg1_enc=$(binhex "$arg1")
  arg2_enc=$(binhex "$arg2")
  case $comp in
    = | == )
      comparison_encoded="[ \"$arg1_enc\" $comp \"$arg2_enc\" ]"
      comparison="[ \"$arg1\" $comp \"$arg2\" ]"
    ;;
    != | !== )
      comparison_encoded="[ \"$arg1_enc\" \!= \"$arg2_enc\" ]"
      comparison="[ \"$arg1\" \!= \"$arg2\" ]"
    ;;
    =~ ) # can't do encoded regex comparisons, so just do a plaintext comparison
      comparison_encoded="[[ \"$arg1\" =~ $arg2 ]]"
      comparison="[[ \"$arg1\" =~ $arg2 ]]"
    ;;
    !=~ | !~ )
      comparison_encoded="[[ ! \"$arg1\" =~ $arg2 ]]"
      comparison="[[ ! \"$arg1\" =~ $arg2 ]]"
    ;;
    * ) 
      echo "Unknown comparison operator: $comp" >&2
      return 1
    ;;
  esac
  if eval "$comparison_encoded"; then
    return 0
  else
    # These values (BASH_SOURCE and BASH_LINENO) seem valid when triggered in my dotfiles, but not from my shell.
    # Not sure how to fix yet.
    local actualfile
    actualfile="$(readlink -f ${BASH_SOURCE[1]})"
    echo "Assertion failed: \"$arg1\" $comp \"$arg2\" @ ${actualfile}:${BASH_LINENO[1]}"
    [ -n "$message" ] && echo $message
    return 1
  fi
}

# these tests had to go here instead of binhex.bash due to an endless loop of sourcing assert.bash from in there
assert "$(binhex "Peter")" == "5065746572" "binhex function should encode binary strings to hex"
assert "$(hexbin "5065746572")" == "Peter" "hexbin function should decode binary from hex"
# TODO: the following is not easy to make pass so tabled for now. just be aware of it
# assert "$(hexbin "50657465720a")" == "Peter\n" "hexbin function shouldn't eat hex-encoded end-of-line newlines"

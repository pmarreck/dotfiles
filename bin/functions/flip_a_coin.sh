flip_a_coin() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  (( RANDOM % 2 )) && echo "heads" || echo "tails"
}

source_relative_once assert.bash

# testing this is interesting...
assert $(RANDOM=0 flip_a_coin) == "tails"
assert $(RANDOM=1 flip_a_coin) == "heads"

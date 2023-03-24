flip_a_coin() {
  (( RANDOM % 2 )) && echo "heads" || echo "tails"
}

source_relative_once bin/functions/assert.bash

# testing this is interesting...
assert $(RANDOM=0 flip_a_coin) == "tails"
assert $(RANDOM=1 flip_a_coin) == "heads"

exit 0 # test fails should not kill the shell here when including this file

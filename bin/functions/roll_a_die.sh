roll_a_die() {

  # so the trick to be strictly correct here is that 32767 is not evenly divisible by 6,
  # so there will be bias UNLESS you cap at 32766
  # since 32766 is evenly divisible by 6 (5461)
  # But for any die size, you now have to find the maximum evenly divisible number
  # that is below 32767...
  local diesides=${1:-6} # default to 6-sided die
  local offset=$((32768 % diesides))
  local max=$((32768 - offset))
  local candidate=$RANDOM
  while [ $candidate -gt $max ]; do
    candidate=$RANDOM
  done
  echo $((1 + candidate % diesides))
}

source_relative_once bin/functions/assert.bash

assert $(RANDOM=5 roll_a_die) == "6"
assert $(RANDOM=6 roll_a_die) == "1"
assert $(RANDOM=7 roll_a_die 20) == "8"

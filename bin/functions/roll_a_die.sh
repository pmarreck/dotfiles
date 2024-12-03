roll_a_die() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # so the trick to be strictly correct here is that 32768 is not evenly divisible by 6,
  # so there will be bias UNLESS you cap at 32766
  # since 32766 is evenly divisible by 6 (5461)
  # But for any die size, you now have to find the maximum evenly divisible number
  # that is at or below 32768...
  local diesides=${1:-6} # default to 6-sided die
  local offset=$((32768 % diesides))
  local max=$((32768 - offset))
  local candidate=$RANDOM
  while [ $candidate -gt $((max-1)) ]; do
    candidate=$RANDOM
  done
  echo $((1 + candidate % diesides))
}
export -f roll_a_die

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  source_relative_once assert.bash

  assert $(RANDOM=5 roll_a_die) == "6"
  assert $(RANDOM=6 roll_a_die) == "1"
  assert $(RANDOM=7 roll_a_die 20) == "8"
fi

# usage: repeat <number of times> <command>
repeat() {
  local count=$1
  local retcodes=0
  shift
  cmd=($@)
  for ((i = 0; i < count; i++)); do
    eval "${cmd[@]}"
    (( retcodes+=$? ))
  done
  return $retcodes
}

source_relative_once bin/functions/assert.bash

assert "$(repeat 3 "echo -n \"hi \"")" == 'hi hi hi '
# ensure return code is summed up from failed commands
assert "$(repeat 3 false; echo $?)" == "3"

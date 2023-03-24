# usage: repeat <number of times> <command>
repeat() {
  local count=$1
  shift
  cmd=($@)
  for ((i = 0; i < count; i++)); do
    eval "${cmd[@]}"
  done
}

source_relative_once bin/functions/assert.bash

assert "$(repeat 3 "echo -n \"hi \"")" == 'hi hi hi '

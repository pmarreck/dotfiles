#!/usr/bin/env bash
# Reads from stdin and beeps on each line.
shopt -s lastpipe
while read input; do   # < <(cat -)
  echo $input
  tput bel
done < /dev/stdin

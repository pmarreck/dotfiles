# Print a string num times. Comes from Perl apparently.
# usage: x string num
x() {
  for i in $(seq 1 $2); do printf "%s" "$1"; done
}
# x with a newline after it
xn() {
  x $1 $2
  # print a newline only if the string does not end in a newline
  [[ "$1" == "${1%$'\n'}" ]] && echo
}

assert $(x a 3) == aaa "x function should repeat a string"
assert "$(xn "a\n" 2)" == "a\na\n" "xn function should repeat a string with a newline"

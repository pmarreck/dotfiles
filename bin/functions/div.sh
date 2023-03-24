# "simulate" decimal division with integers and a given number of significant digits of the mantissa
# without using bc or awk because I hate firing up a new process for something so simple
div() {
  local sd=${3:-2}
  case $1 in
  -h | --help | "")
    echo "Divide two numbers as decimal, not integer"
    echo "Usage: div <numerator> <denominator> [<digits after decimal point, defaults to 2>]"
    echo "This function is defined in $BASH_SOURCE"
    echo "Note that the result is truncated to $sd significant digits after the decimal point,"
    echo "NOT rounded from the next decimal place."
    echo "Also, things get weird with big arguments; compare 'div 1234234 121233333 5' with 'div 1234234 121233333 50'."
    echo "Not sure why, yet; possibly internal bash integer overflow."
    ;;
  *)
    printf "%.${sd}f\n" "$((10**${sd} * ${1}/${2}))e-${sd}"
    ;;
  esac
}

source_relative_once bin/functions/assert.bash

assert "$(div 22 15)" == "1.46"
assert "$(div 1234234 121233333 5)" == "0.01018"

exit 0 # test fails should not kill the shell here when including this file

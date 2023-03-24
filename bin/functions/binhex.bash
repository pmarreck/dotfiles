# add binhex command to dump hex from stdin or args (note that hexdump also exists)
# usage: echo "peter" | binhex
# or: binhex peter
binhex() {
# echo "PATH from binhex: $PATH" >&2
  if [ -z "$1" ]; then # if no arguments
    # The following exits code 0 if stdin not empty; 1 if empty; does not consume any bytes.
    # This may only be a Bash-ism, FYI. Not sure if it's shell-portable.
    # read -t 0
    # retval=${?##1} # replace 1 with blank so it falses correctly if stdin is empty
    if read -t 0; then
      xxd -pu  # receive piped input from stdin
    else # if stdin is empty AND no arguments
      echo "Usage: binhex <string>"
      echo "       (or pipe something to binhex)"
      echo "This function is defined in ${BASH_SOURCE[0]}"
    fi
  else # if arguments
    printf "%b" "$1" | xxd -pu # pipe all arguments to xxd
  fi
}

# convert hex back to binary
hexbin() {
  if [ -z "$1" ]; then # if no arguments
    # The following exits code 0 if stdin not empty; 1 if empty; does not consume any bytes.
    # This may only be a Bash-ism, FYI. Not sure if it's shell-portable.
    if read -t 0; then
      xxd -r -p   # receive piped input from stdin
    else # if stdin is empty AND no arguments
      echo "Usage: hexbin <hex string>"
      echo "       (or pipe something to hexbin)"
      echo "This function is defined in ${BASH_SOURCE[0]}"
    fi
  else # if arguments
    printf "%b" "$1" | xxd -r -p  # pipe all arguments to xxd
  fi
}

# tests for these functions are currently in assert.bash, it's explained why there;
# in short, avoiding circular deps

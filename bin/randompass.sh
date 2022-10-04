#!/usr/bin/env bash

# get a random-character password
# First argument is password length
# Can override the default character set by passing in PWCHARSET=<charset> as env

# Set up a few character set globals in ENV

export CHARSET_LOWER="$(echo -n {a..z} | tr -d ' ')"
export CHARSET_UPPER="$(echo -n {A..Z} | tr -d ' ')"
export CHARSET_NUM="$(echo -n {0..9} | tr -d ' ')"
export CHARSET_ALPHA="$CHARSET_LOWER$CHARSET_UPPER"
export CHARSET_ALNUM="$CHARSET_ALPHA$CHARSET_NUM"
# delete glyphs that can be confused with other characters
export CHARSET_ALNUM_SANE="$(printf "%s" "$CHARSET_ALNUM" | tr -d 'OlI')"
export CHARSET_PUNC='!@#$%^&*-_=+[]{}|;:,.<>/?~'
export CHARSET_HEX="${CHARSET_NUM}abcdef"

randompass() {
  needs shuf
  # globbing & history expansion here is a pain, so we store its state, temp turn it off & restore it later
  local maybeglob="$(shopt -po noglob histexpand)"
  set -o noglob # turn off globbing
  set +o histexpand # turn off history expansion
  if [ $# -eq 0 ]; then
    echo "Usage: randompass <length>"
    echo "This function is defined in $BASH_SOURCE"
    echo "You can override the default character set CHARSET_ALNUM_SANE by passing in PWCHARSET=<charset> as env"
    echo "where <charset> is one or more of:"
    echo "CHARSET_LOWER, CHARSET_UPPER, CHARSET_NUM, CHARSET_ALPHA, CHARSET_ALNUM, CHARSET_ALNUM_SANE, CHARSET_PUNC, CHARSET_HEX"
    return 1
  fi
  # allow overriding the password character set with env var PWCHARSET
  # NOTE that we DELETE THE CAPITAL O, CAPITAL I, LOWERCASE L CHARACTERS
  # DUE TO SIMILARITY TO 1 AND 0 (which we leave in)
  # (but only if you use the default "sane alnum" set)
  # BECAUSE WHO THE FUCK EVER THOUGHT THAT WOULD BE A GOOD IDEA? 😂
  local PWCHARSET="${PWCHARSET:-$CHARSET_ALNUM_SANE}"
  # ...but also intersperse it with spaces so that the -e option to shuf works.
  # Using awk to split the character set into a space-separated string of characters.
  # Saw some noise that empty field separator will cause awk problems,
  # but it's concise and fast and works, so... &shrug;
  # printf is necessary due to some of the punctuation characters being interpreted when using echo
  local characterset=$(printf "%s" "$PWCHARSET" | awk NF=NF FS="")
  # using /dev/random to enforce entropy, but use urandom if you want speed
  { shuf --random-source=/dev/random -n $1 -er $characterset; } | tr -d '\n'
  echo
  # restore any globbing state
  eval "$maybeglob"
  # cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9\!\@\#\$\%\&\*\?' | fold -w $1 | head -n 1
}

# get a random-dictionary-word password
# First argument is number of words to generate
# Second argument is minimum word length
randompassdict() {
  needs shuf
  if [ $# -eq 0 ]; then
    echo "Usage: randompassdict <num-words> [<min-word-length default 8> [<max-word-length default 99>]]"
    echo "This function is defined in $BASH_SOURCE"
    if [ "$PLATFORM" = "linux" ]; then
      echo "Note that on linux, this may require installation of the 'words' package"
      echo "or on NixOS, setting 'environment.wordlist.enable = true;' in your configuration.nix"
      echo "(which adds the 'scowl' package to your system)"
    fi
    return 1
  fi
  local dict_loc="/usr/share/dict/words"
  [ -f "$dict_loc" ] || { echo "$dict_loc missing. May need to install 'words' package. Exiting."; return 1; }
  local numwords=$1
  local minlen=${2:-8}
  local maxlen=${3:-99}
  # take the dict, filter out anything not within the min/max length or that has apostrophes, and shuffle
  local pool=$(cat /usr/share/dict/words | awk 'length($0) >= '$minlen' && length($0) <= '$maxlen' && $0 ~ /^[^'\'']+$/')
  local poolsize=$(printf "%s" "$pool" | wc -l)
  # why is poolsize getting spaces in front? No idea. Removing them.
  poolsize=${poolsize##* }
  local words=$(echo -n "$pool" | shuf --random-source=/dev/random -n "$numwords" | tr '\n' ' ')
  echo "$words"
  echo "(out of a possible $poolsize available words in the dictionary that suit the requested length range [$minlen-$maxlen])" 1>&2
  # a former attempt that worked but was less flexible:
  #cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9\!\@\#\$\%\&\*\?' | fold -w $1 | head -n $2 | tr '\n' ' '
}

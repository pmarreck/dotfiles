#!/usr/bin/env bash

# Encryption functions. Requires the GNUpg "gpg" commandline tool. On OS X, "brew install gnupg"
# Explanation of options here:
# --symmetric - Don't public-key encrypt, just symmetrically encrypt in-place with a passphrase.
# -z 9 - Compression level
# --require-secmem - Require use of secured memory for operations. Bails otherwise.
# cipher-algo, s2k-cipher-algo - The algorithm used for the secret key
# digest-algo - The algorithm used to mangle the secret key
# s2k-mode 3 - Enables multiple rounds of mangling to thwart brute-force attacks
# s2k-count 65000000 - Mangles the passphrase this number of times. Takes over a second on modern hardware.
# compress-algo BZIP2- Uses a high quality compression algorithm before encryption. BZIP2 is good but not compatible with PGP proper, FYI.
encrypt() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs gpg
  case "$1" in
  -h | --help | "")
    echo 'Usage: encrypt <filepath>'
    echo "This function is defined in ${BASH_SOURCE[0]}"
    echo 'Will ask for password and write <filepath>.gpg to same directory.'
    ;;
  *)
    >&2 echo -e "${ANSI}${TXTYLW}gpg --symmetric -z 9 --require-secmem --cipher-algo AES256 --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000 --compress-algo BZIP2 $* ${ANSI}${TXTRST}"
    gpg --symmetric -z 9 --require-secmem --cipher-algo AES256 --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000 --compress-algo BZIP2 "$*"
    ;;
  esac
}
# note: will decrypt to STDOUT by default, for security reasons.
decrypt() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs gpg
  case "$1" in
  -h | --help | "")
    echo 'Usage: decrypt [-o] <filepath.gpg>'
    echo "This function is defined in ${BASH_SOURCE[0]}"
    echo 'Will ask for password and *output cleartext to stdout* for security reasons; redirect to file with > to write to disk,'
    echo 'or pass -o option which will write to the original filename stored inside the file.'
    ;;
  -o)
    shift
    >&2 echo -e "${ANSI}${TXTYLW}gpg ${*}${ANSI}${TXTRST}"
    gpg "$@"
    ;;
  *)
    >&2 echo -e "${ANSI}${TXTYLW}gpg -d ${*}${ANSI}${TXTRST}"
    gpg -d "$@"
    ;;
  esac
}

#!/usr/bin/env bash

# digital clock
# not sure why it updates so slowly; all the subshells and evals?
clock() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  _read_clock_font_data() {
    # reads everything in this file below __DATA__
    $SED '0,/^__DATA__$/d' "$BASH_SOURCE"
  }
  _decode_data() {
    # decodes base64-encoded data
    base64 -d
  }
  _decompress_data() {
    # extract 7zip data from stdin and ship to stdout
    # note: in order to use both stdin and stdout, have to use xz format
    # which has same compression as 7z but supports streaming
    # (7z archives can only support "seek" operations)
    7z e -txz -si -so
  }
  _clock_font_bin() {
    # reads the data from this file, decodes it, and decompresses it
    _read_clock_font_data | _decode_data | _decompress_data
  }
  F=($(_clock_font_bin | hexdump -v -e'1/1 "%x\n"'))
  e=echo\ -e;$e "\033[2J\033[?25l"; while true; do A=''  T=`date +" "%H:%M:%S`
  $e "\033[0;0H" ; for c in `eval $e {0..$[${#T}-1]}`; do a=`$e -n ${T:$c:1}|\
  hexdump -v -e'1/1 "%u\n"' `; A=$A" "$[32+8*a]; done;for j in {0..7};do for \
  i in $A; do d=0x${F[$[i+j]]} m=$((0x80)); while [ $m -gt 0 ] ; do bit=$[d&m]
  $e -n $[bit/m]|sed -e 'y/01/ ▀/';: $[m>>=1];done;done;echo;done;done # BruXy
}
# export -f clock

###### END OF CODE ######
##### START OF DATA #####
# if this script is sourced, return; otherwise it will error, and exit
return 0 2>/dev/null || exit 0
# the bitmap font is "drdos8x8.psfu", available in most "fonts" packages
# ... but I don't like dependencies, so I've included it here, 7zipped and base64-encoded
__DATA__
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
AKZSicUAAe4U9yYAACGLCl0+MA2LAgAAAAABWVo=

#!/usr/bin/env bash

_read_font_data() {
  # reads everything in this file below __FONT__ and base64-decodes it
  sed '0,/^__DATA__$/d' "$BASH_SOURCE" | base64 -d
}

# digital clock
clock() {
  F=($(_read_font_data | 7z e -si -so | hexdump -v -e'1/1 "%x\n"'))
  e=echo\ -e;$e "\033[2J\033[?25l"; while true; do A=''  T=`date +" "%H:%M:%S`
  $e "\033[0;0H" ; for c in `eval $e {0..$[${#T}-1]}`; do a=`$e -n ${T:$c:1}|\
  hexdump -v -e'1/1 "%u\n"' `; A=$A" "$[32+8*a]; done;for j in {0..7};do for \
  i in $A; do d=0x${F[$[i+j]]} m=$((0x80)); while [ $m -gt 0 ] ; do bit=$[d&m]
  $e -n $[bit/m]|sed -e 'y/01/ ▀/';: $[m>>=1];done;done;echo;done;done # BruXy
}

# the bitmap font is "drdos8x8.psfu", available in most "fonts" packages
# ... but I don't like dependencies, so I've included it here, 7zipped and base64-encoded
__DATA__
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

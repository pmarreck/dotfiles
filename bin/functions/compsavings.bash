#!/usr/bin/env bash

# Get the zfs compression savings for every file or directory in this directory
# FIXME: Currently borked. Need to fix
# zfs_compsavings() {
#   echo "actual compressed savings  filename"
#   echo "------ ---------- -------- --------"
#   for i in `pwd`/* ; do
#     actualsize=`du --apparent-size -s "$i" | awk '{print $1}'`
#     # some files are 0 bytes, and we don't like dividing by zero
#     if [ $actualsize = "0" ]; then
#       actualsize="1"
#     fi
#     # actualsize_h=`SIZE=1K du -sh "$i" | awk '{print $1}'`
#     compressedsize=`du -s "$i" | awk '{print $1}'`
#     # compressedsize_h=`du -h -s "$i" | awk '{print $1}'`
#     ratio=`echo "scale=2; print ($actualsize/$compressedsize*100)" | bc`
#     file=`basename "$i"`
#     printf "%6s %10s %8s %s\n" "${actualsize}" "${compressedsize}" "${ratio}%" "$file"
#   done
# }

# First function written by GPT-4/ChatGPT, worked on the first try with only minor edits!
# ...Aaaand still gives wonky-looking results sometimes. No time to investigate.
compsavings() {
  if [ -z "$1" ]; then
    echo "Usage: compsavings /path/to/directory"
    return 2
  fi
  directory_path=$1
  real_size=$(du -s --block-size=1 --apparent-size "$directory_path" 2>/dev/null | awk '{print $1}')
  compressed_size=$(du -s --block-size=1 "$directory_path" 2>/dev/null | awk '{print $1}')
  percentage_saved=$(echo "scale=2; (($real_size - $compressed_size) * 100) / $real_size" | bc)
  echo "Real size:        $real_size bytes"
  echo "Compressed size:  $compressed_size bytes"
  echo "Percentage saved: ${percentage_saved}%"
}

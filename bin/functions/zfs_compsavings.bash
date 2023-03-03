# Get the zfs compression savings for every file or directory in this directory
# FIXME: Currently borked. Need to fix
zfs_compsavings() {
  echo "actual compressed savings  filename"
  echo "------ ---------- -------- --------"
  for i in `pwd`/* ; do
    actualsize=`du --apparent-size -s "$i" | awk '{print $1}'`
    # some files are 0 bytes, and we don't like dividing by zero
    if [ $actualsize = "0" ]; then
      actualsize="1"
    fi
    # actualsize_h=`SIZE=1K du -sh "$i" | awk '{print $1}'`
    compressedsize=`du -s "$i" | awk '{print $1}'`
    # compressedsize_h=`du -h -s "$i" | awk '{print $1}'`
    ratio=`echo "scale=2; print ($actualsize/$compressedsize*100)" | bc`
    file=`basename "$i"`
    printf "%6s %10s %8s %s\n" "${actualsize}" "${compressedsize}" "${ratio}%" "$file"
  done
}

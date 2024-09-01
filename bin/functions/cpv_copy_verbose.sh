# "copy verbose" - copy a file or directory, showing progress
# example: cpv ~/Documents /mnt/Backup
# This copies the entire ~/Documents directory to /mnt/Backup/Documents, showing progress
cpv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local real_source_path="$(realpath "$1")"
  # ensure real_source_path is a real directory or file
  if [ ! -e "$real_source_path" ]; then
    echo "Error: $1 does not exist" 1>&2
    return 1
  fi
  local sourcedir="$(dirname "$real_source_path")"
  local destdir="$(realpath "$2")"
  # ensure destdir is a directory that exists
  if [ ! -d "$destdir" ]; then
    echo "Destination directory $destdir does not exist." 1>&2
    return 1
  fi
  local size_bytes=$(du -sb "$real_source_path" | awk '{print $1}')
  local size_metadata=$(du -s --inodes "$real_source_path" | awk '{print $1}')
  local size_total=$(($size_bytes + $size_metadata))
  local filename="$(basename "$real_source_path")"
  pushd "$sourcedir" > /dev/null
  tar cf - "$filename" | pv -c -s $size_total | tar xf - -C "$destdir"
  popd > /dev/null
}

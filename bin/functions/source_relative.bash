# Source a file relative to the current file.
# Only redefines it here if it's not already defined.
# Since we need a way to reload this if editing it, we will use the same
# global variable that is unset in the "rehash" function that reloads the dotfiles
# and which is actually set in these functions.
[ -v _SOURCED_FILES ] || \
source_relative() {
  # _dir_name=`dirname "$0"` # doesn't work reliably
  _dir_name=`dirname "${BASH_SOURCE[0]}"` # works in bash but not POSIX compliant sh
  _temp_path=`cd "$_dir_name" && pwd`
  # $_TRACE_SOURCING && echo "Sourcing $temp_path/$1" >&2
  . "$_temp_path/$1"
  unset _dir_name _temp_path
}

# Define the source_relative_once function
# export _TRACE_SOURCING=true
[ -v _SOURCED_FILES ] || \
source_relative_once() {
  local _file="$1"
  # Get the directory of the currently executing script
  # _dir=`dirname "$0"` # doesn't work reliably
  local _dir=`dirname "${BASH_SOURCE[0]}"` # works in bash but not POSIX compliant sh
  
  # Convert the relative path to an absolute path
  local _abs_path="$_dir/$_file"
  local _abs_dirname=`dirname "$_abs_path"`
  _abs_dirname=`cd "$_abs_dirname" && pwd`
  local _abs_filename=`basename "$_abs_path"`
  local _abs_path="$_abs_dirname/$_abs_filename"

  # test if _abs_path is empty
  if [ -z "$_abs_path" ]; then
    echo "Error in source_relative_once: \$_abs_path is blank" >&2
    return
  fi

  if [ ! -e "$_abs_path" ]; then
    echo "Error in source_relative_once: could not find file $_abs_path" >&2
    return
  fi

  # check if it is a softlink; if so, resolve it to the actual path
  if [ -L "$_abs_path" ]; then
    _abs_path=`realpath "$_abs_path"`
  fi

  # Check if the file has already been sourced
  if [[ " ${_SOURCED_FILES} " =~ " ${_abs_path} " ]]; then
    $_TRACE_SOURCING && echo "Already sourced \"$_abs_path\"" >&2
    return
  fi
  $_TRACE_SOURCING && local _debug_id=$RANDOM
  # If the file hasn't been sourced yet, source it and add it to the list of sourced files
  $_TRACE_SOURCING && echo "$_debug_id Sourcing (once?) \"$_abs_path\"" >&2
  $_TRACE_SOURCING && echo "$_debug_id prior to sourcing, _SOURCED_FILES is now \"${_SOURCED_FILES}\"" >&2
  if [ -z "$_SOURCED_FILES" ]; then
    export _SOURCED_FILES="$_abs_path"
  else
    export _SOURCED_FILES="$_abs_path $_SOURCED_FILES"
  fi
  source "$_abs_path"
  $_TRACE_SOURCING && echo "$_debug_id after sourcing \"$_abs_path\", _SOURCED_FILES is now \"${_SOURCED_FILES}\"" >&2
  return 0 # or else this exits nonzero and breaks other things
}

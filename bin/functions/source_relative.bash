# Source a file relative to the current file.
# Only redefines it here if it's not already defined.
# Since we need a way to reload this if editing it, we will use the same
# global variable that is unset in the "rehash" function that reloads the dotfiles
# and which is actually set in these functions.
[ -v _SOURCED_FILES ] || \
source_relative() {
  # _dir_name=`dirname "$0"` # doesn't work reliably
  _dir_name=`dirname "${BASH_SOURCE[1]}"` # works in bash but not POSIX compliant sh
  _temp_path=`cd "$_dir_name" && pwd`
  [ -v _TRACE_SOURCING ] && echo "Sourcing $temp_path/$1" >&2
  . "$_temp_path/$1"
  unset _dir_name _temp_path
}

# Define the source_relative_once function
# export _TRACE_SOURCING=true
[ -v _SOURCED_FILES ] || \
source_relative_once() {
  [ -v _TRACE_SOURCING ] && local _debug_id=$RANDOM
  local _file="$1"
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: _file is $_file"
  # Get the directory of the currently executing script
  # _dir=`dirname "$0"` # doesn't work reliably
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: BASH_SOURCE[1] is ${BASH_SOURCE[1]}"
  local _dir=`dirname "${BASH_SOURCE[1]}"` # works in bash but not POSIX compliant sh
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: _dir is $_dir"
  # Convert the relative path to an absolute path
  local _abs_path="$_dir/$_file"
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: _abs_path is $_abs_path"
  local _abs_temp_dirname=`dirname "$_abs_path"`
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: _abs_temp_dirname is $_abs_temp_dirname"
  local _abs_dirname=`cd "$_abs_temp_dirname" && pwd`
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: _abs_dirname after cd/pwd is $_abs_dirname"
  # test if _abs_dirname is empty
  if [ -z "$_abs_dirname" ]; then
    echo "Error in source_relative_once: $_abs_temp_dirname is not a valid directory" >&2
    return
  fi
  local _abs_filename=`basename "$_abs_path"`
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: _abs_filename after basename is $_abs_filename"
  local _abs_path="$_abs_dirname/$_abs_filename"
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: _abs_path after recombining is $_abs_path"
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
    [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: Already sourced \"$_abs_path\"" >&2
    return
  fi
  # If the file hasn't been sourced yet, source it and add it to the list of sourced files
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: Sourcing (once?) \"$_abs_path\"" >&2
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: prior to sourcing, _SOURCED_FILES is now \"${_SOURCED_FILES}\"" >&2
  if [ -z "$_SOURCED_FILES" ]; then
    # So the reason why we DO NOT export this is to force reloading of all dotfiles in a new shell
    _SOURCED_FILES="$_abs_path"
  else
    _SOURCED_FILES="$_abs_path $_SOURCED_FILES"
  fi
  source "$_abs_path"
  [ -v _TRACE_SOURCING ] && echo "source_relative_once invocation #${_debug_id}: after sourcing \"$_abs_path\", _SOURCED_FILES is now \"${_SOURCED_FILES}\"" >&2
  return 0 # or else this exits nonzero and breaks other things
}

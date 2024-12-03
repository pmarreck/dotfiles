source_relative_once assert.bash

# function to find necessary binaries in common locations in case PATH is borked
find_binary() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if [ -f "/run/current-system/sw/bin/$1" ]; then
    echo -n "/run/current-system/sw/bin/$1"
  elif [ -f "/usr/local/bin/$1" ]; then
    echo -n "/usr/local/bin/$1"
  elif [ -f "/usr/sbin/$1" ]; then
    echo -n "/usr/sbin/$1"
  elif [ -f "/usr/bin/$1" ]; then
    echo -n "/usr/bin/$1"
  elif [ -f "/bin/$1" ]; then
    echo -n "/bin/$1"
  elif [ -f "/sbin/$1" ]; then
    echo -n "/sbin/$1"
  else
    echo "ERROR: Could not find $1 without PATH" >&2
    return 1
  fi
}
export -f find_binary

export AWK=$(find_binary awk)
export SED=$(find_binary sed)

# function to prepend paths in an idempotent way
prepend_path() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  function docs() {
    echo "Usage: prepend_path [-o|-h|--help] <path_to_prepend> [name_of_path_var, defaults to PATH]" >&2
    echo "Setting -o will print the new path to stdout instead of exporting it" >&2
    echo "Env var IGNORE_PREPEND_PATH_WARNINGS=true will suppress warnings" >&2
  }
  local stdout=false
  local IGNORE_PREPEND_PATH_WARNINGS=${IGNORE_PREPEND_PATH_WARNINGS:-false}
  case "$1" in
    -h|--help)
      docs
      return 0
      ;;
    -o)
      stdout=true
      shift
      ;;
    *)
      ;;
  esac
  local dir="${1%/}"     # discard trailing slash
  local var="${2:-PATH}"
  if [ -z "$dir" ]; then
    docs
    return 2 # incorrect usage return code, may be an informal standard
  fi
  case "$dir" in
    /*) :;; # absolute path, do nothing
    *) $IGNORE_PREPEND_PATH_WARNINGS || echo "prepend_path warning: '$dir' is not an absolute path, which may be unexpected" >&2;;
  esac
  local newpath=${!var}
  [ -n "${DEBUG_PATHCONFIG}" ] && echo "Upon entry to prepend_path($dir), ${var} is ${!var}" >&2
  if [ -z "$newpath" ]; then
    $stdout || $IGNORE_PREPEND_PATH_WARNINGS || echo "prepend_path warning: $var was empty, which may be unexpected: setting to $dir" >&2
    $stdout && echo "$dir" || export ${var}="$dir"
    return
  fi
  # prepend to front of path
  newpath="$dir:$newpath"
  # remove all duplicates, retaining the first one encountered
  newpath=$(echo -n $newpath | awk -v RS=: -v ORS=: '!($0 in a) {a[$0]; print}')
  # remove trailing colon (awk's ORS (output record separator) adds a trailing colon)
  newpath=${newpath%:}
  [ -n "${DEBUG_PATHCONFIG}" ] && echo "After prepend_path($dir), ${var} is now $newpath" >&2
  $stdout && echo "$newpath" || export ${var}="$newpath"
}
export -f prepend_path

# super compact prepend-path
# Usage examples:
#   PATH="$(ppp /usr/local/bin)"
#   export PATH="$(ppp /usr/local/bin PATH)"
#   LD_LIBRARY_PATH=$(ppp /usr/local/lib LD_LIBRARY_PATH)
# Does anyone actually still use or need histexpand? Opinion: Unexpected behavior in strings that may occasionally contain '!' is not worth the functionality. So I turn it off here, because it caused a bug with the ${!plv} dereferencing expression, and I don't bother restoring it.
ppp() { set +H; local plv="${2:-PATH}"; echo -n "${1%/}:${!plv}" | awk -v RS=: -v ORS=: '!($0 in a) {a[$0]; print}' | $SED 's/:$//'; }

exclude_path() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local AWK=$(which awk || echo -n "/run/current-system/sw/bin/awk") # in case you accidentally exclude the path that has awk...
  function docs() {
    echo "Usage: exclude_path [-o|-h|--help] <path_to_exclude> [name_of_path_var, defaults to PATH]" >&2
    echo "Setting -o will print the new path to stdout instead of exporting it" >&2
  }
  local stdout=false
  local IGNORE_EXCLUDE_PATH_WARNINGS=${IGNORE_EXCLUDE_PATH_WARNINGS:-false}
  case "$1" in
    -h|--help)
      docs
      return 0
      ;;
    -o)
      stdout=true
      shift
      ;;
    *)
      ;;
  esac
  local dir="${1%/}"  # discard trailing slash
  local var="${2:-PATH}"
  if [ -z "$dir" ]; then
    docs
    return 2  # incorrect usage return code
  fi
  case "$dir" in
    /*) :;;  # absolute path, do nothing
    *) $IGNORE_EXCLUDE_PATH_WARNINGS || echo "exclude_path warning: '$dir' is not an absolute path, which may be unexpected" >&2;;
  esac
  local paths=${!var}
  [ -n "${DEBUG_PATHCONFIG}" ] && echo "Upon entry to exclude_path($dir), ${var} is ${!var}" >&2
  if [ -z "$paths" ]; then
    $stdout || $IGNORE_EXCLUDE_PATH_WARNINGS || echo "exclude_path warning: $var is empty, nothing to exclude" >&2
    return
  fi
  # Filter out the specified directory
  local newpath=$(echo -n "$paths" | $AWK -v RS=: -v ORS=: -v path="$dir" '$0 != path')
  # Remove trailing colon (awk's ORS (output record separator) adds a trailing colon)
  newpath=${newpath%:}
  [ -n "${DEBUG_PATHCONFIG}" ] && echo "After exclude_path($dir), ${var} is now $newpath" >&2
  $stdout && echo "$newpath" || export ${var}="$newpath"
}
export -f exclude_path

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  # INLINE RUNTIME TEST SUITE
  export _FAKEPATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export _FAKEPATHDUPES="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export _FAKEPATHCONSECUTIVEDUPES="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export _FAKEPATH1="/usr/bin"
  export _FAKEPATHBLANK=""
  assert $(prepend_path -o /usr/local/bin _FAKEPATH) == "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "prepend_path failed when the path was already in front"
  assert $(prepend_path -o /usr/sbin _FAKEPATH) == "/usr/sbin:/usr/local/bin:/usr/bin:/bin:/sbin" \
    "prepend_path failed when the path was already in the middle"
  assert $(prepend_path -o /sbin _FAKEPATH) == "/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin" \
    "prepend_path failed when the path was already at the end"
  assert $(prepend_path -o /usr/local/bin _FAKEPATHBLANK) == "/usr/local/bin" \
    "prepend_path failed when the path was blank"
  assert $(prepend_path -o /usr/local/bin _FAKEPATH1) == "/usr/local/bin:/usr/bin" \
    "prepend_path failed when the path just had 1 value"
  assert $(prepend_path -o /usr/bin _FAKEPATH1) == "/usr/bin" \
    "prepend_path failed when the path just had 1 value and it's the same"
  assert $(prepend_path -o /usr/bin _FAKEPATHDUPES) == "/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin" \
    "prepend_path failed when there were multiple copies of it already in the path"
  assert $(prepend_path -o /usr/local/bin _FAKEPATHCONSECUTIVEDUPES) == "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "prepend_path failed when there were multiple consecutive copies of it already in the path and it is also already in front"
  unset _FAKEPATH
  unset _FAKEPATHDUPES
  unset _FAKEPATHCONSECUTIVEDUPES
  unset _FAKEPATH1
  unset _FAKEPATHBLANK
fi

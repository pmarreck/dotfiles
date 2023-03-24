# my version of find file
# ff [[<start path, defaults to .>] <searchterm>] (ff with no arguments lists all files recursively from $PWD)
# so fd on linux when installed via apt has the name fdfind, complicating matters
fdbin=fd
command -v $fdbin >/dev/null 2>&1 || fdbin=fdfind
command -v $fdbin >/dev/null 2>&1 || fdbin=fd
ff() {
  needs $fdbin cargo install fd-find or apt install fd-find \(binary is named fdfind then\)
  case $1 in
  -h | --help)
    echo "Find File (pmarreck wrapper function)"
    echo 'Usage: ff [<start path> <searchterm> | "<searchterm>" <start path> | <searchterm>]'
    echo '(defaults to starting in current directory if no valid directory argument is provided)'
    echo "This function is defined in ${BASH_SOURCE[0]}"
    echo '(ff with no arguments lists all files recursively from $PWD)'
    ;;
  *)
    local dir=""
    local term=""
    # I did this logic because I got tired of remembering whether the (optional) directory argument was
    # the first or second argument, lol. (Computers are smart, they can make this easier!)
    # If either of the first 2 arguments is a valid directory, use that as the directory argument
    # and use the other argument (or the rest of the arguments if the directory argument was the first argument)
    # as the search query.
    # If no valid directory argument is provided, default to the current directory
    # and use all arguments as a search term.
    [ -d "$2" ] && dir="$2" && term="$1"
    [ -d "$1" ] && dir="$1" && shift && term="$*"
    [ -z "$dir" ] && dir="$PWD" && term="$*" && echo -e "${ANSI}${TXTYLW}Searching from current directory ${PWD}...${ANSI}${TXTRST}" >&2
    # search all hidden and gitignore'd files
    # Note: Not including -jN argument (where N is a lowish number)
    # currently results in massive slowdown due to bug: https://github.com/sharkdp/fd/issues/1131
    # I made it -j2 after some testing
    >&2 echo -e "${ANSI}${TXTYLW}${fdbin} -j2 -HI \"${term}\" \"${dir}\"${ANSI}${TXTRST}"
    $fdbin -j2 -HI "$term" "$dir"
    ;;
  esac
}

source_relative_once bin/functions/assert.bash

# inline ff test
_fftest() {
  local - # scant docs on this but this apparently automatically resets shellopts when the function exits
  set -o errexit
  local _testlocname=$(randompass 10)
  if assert "${#_testlocname}" == "10" "Generated test location name for ff test is not working: ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"; then
    local _testloc="/tmp/$_testlocname"
    # the point of [ 1 == 0 ] below is to fail the line and trigger errexit IF errexit is set
    mkdir -p $_testloc >/dev/null 2>&1 || ( echo "Cannot create test directory '$_testloc' in ff test: ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"; [ 1 == 0 ] )
    touch $_testloc/$_testlocname
    pushd $_testloc >/dev/null
    assert $(ff $_testlocname 2>/dev/null) == "$_testloc/$_testlocname"
    assert $(ff 2>/dev/null) == "$_testloc/$_testlocname"
    popd >/dev/null
    pushd $HOME >/dev/null
    assert $(ff $_testloc $_testlocname 2>/dev/null) == "$_testloc/$_testlocname"
    assert $(ff $_testlocname $_testloc 2>/dev/null) == "$_testloc/$_testlocname"
    popd >/dev/null
    rm $_testloc/$_testlocname
    rm -d $_testloc
  fi
}
_fftest # why the frick is this taking a half second to run??
# ...EDIT: Turns out to be an fd bug, I put in a workaround: https://github.com/sharkdp/fd/issues/1131
assert $- !=~ e "errexit shellopt is still set after function exit: ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"
unset _fftest
# end inline ff test

exit 0 # test fails should not kill the shell here when including this file

# Define the truthy function; keep it POSIX-compatible
truthy() {
  # Check if EDIT is set and not empty, then unset and call edit_function
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return

  var_name="$1"

  # 1. Make sure the argument looks like a valid shell variable name
  if ! echo "$var_name" | grep -Eq '^[a-zA-Z_][a-zA-Z0-9_]*$'; then
    echo "Error: '$var_name' is not a valid shell variable name" >&2
    return 2
  fi

  # 2. Check if the variable exists; if not, always false
  eval "test -n \"\${$var_name+set}\"" || return 1

  # 3. POSIX-compatible way to get the value of the variable
  value=$(eval echo \$$var_name)

  [ "$value" = "true" ] ||[ "$value" = "1" ]
}

# Define the falsey function in terms of the truthy function
falsey() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "$0" "$0" && return

  truthy "$1" && return 1 || return 0
}


# tests
if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  source_relative_once assert.bash
  _a=1
  _b=true
  _d=0
  _e=false
  truthy _a
  assert "$?" == "0"
  truthy _b
  assert "$?" == "0"
  truthy _c
  assert "$?" == "1"
  truthy _d
  assert "$?" == "1"
  truthy _e
  assert "$?" == "1"
  falsey _a
  assert "$?" == "1"
  falsey _b
  assert "$?" == "1"
  falsey _c
  assert "$?" == "0"
  falsey _d
  assert "$?" == "0"
  falsey _e
  assert "$?" == "0"
  unset _a _b _c _d _e
fi

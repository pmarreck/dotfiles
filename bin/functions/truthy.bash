# Define the truthy function
truthy() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local var_name="$1"
  local value="${!var_name}"  # Indirect expansion to get the value of the variable; depends on Bash
  # value=$(eval echo \$$var_name)  # POSIX-compatible way to get the value of the variable

  if [[ "$value" == "1" || "$value" == "true" ]]; then
    true
  else
    false
  fi
}

# Define the falsey function
falsey() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if truthy "$1"; then
    false
  else
    true
  fi
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

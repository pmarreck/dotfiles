#!/usr/bin/env bash

# Print out the names of all executables available in your PATH
executables() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # Use null bytes as delimiter
  # ...found these quote escapes via trial and error, because Bash
  pathdirs="${PATH//:/$'\\\0'}"
  # Loop over null-separated strings
  while IFS= read -rd '\0' dir; do
    # echo "Checking $dir" >&2
    if [ -d "$dir" ]; then  
      find "$dir" -mindepth 1 -maxdepth 1 -xtype f -executable -print 2>/dev/null
    else
      echo "FYI: Directory $dir in your PATH does not exist" >&2
    fi
  done <<<"$pathdirs" | xargs -d '\n' basename --multiple | sort -u # sort with unique
}

# Print out the names of all defined functions
functions() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # declare -F | awk '{print $NF}'
  compgen -A function
}

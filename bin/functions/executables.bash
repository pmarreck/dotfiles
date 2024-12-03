#!/usr/bin/env bash

# Print out the names of all executables available in your PATH
executables() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # Use newline as delimiter for PATH directories
  pathdirs="${PATH//:/$'\n'}"

  # Feature test to determine if '-executable' is supported
  if find /tmp -executable 2>/dev/null | grep -q .; then
    find_option='-executable'
  else
    find_option='-perm +111'
  fi

  # Initialize an empty array to hold all executables
  all_executables=()
  nonexistent_paths=()

  # Loop over newline-separated strings
  while IFS= read -r dir; do
    # Uncomment for debugging: echo "Checking $dir" >&2
    if [ -d "$dir" ]; then
      # Append found executables to the array
      while IFS= read -r exe; do
        all_executables+=("$exe")
      done < <(find "$dir" -mindepth 1 -maxdepth 1 $find_option -type f -print 2>/dev/null | awk -F/ '{print $NF}')
    else
      nonexistent_paths+=("FYI: Directory $dir in your PATH does not exist")
    fi
  done <<<"$pathdirs"

  # Sort and remove duplicates from the complete list of executables
  printf "%s\n" "${all_executables[@]}" | sort -uf
  note "${nonexistent_paths[@]}"
}
export -f executables

# Print out the names of all defined functions
functions() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # declare -F | awk '{print $NF}'
  compgen -A function
}
export -f functions

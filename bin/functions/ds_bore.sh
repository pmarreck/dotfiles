#!/usr/bin/env bash

# graceful dependency enforcement
# Usage: needs <executable> ["provided by <packagename>"]
[[ $(type -t needs) == "function" ]] || needs() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin=$1
  shift
  command -v $bin >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

ds_bore() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs rg "ripgrep is not installed. Please install it and try again." || return 1
  case $1 in
    -h|--help)
      echo "Usage: ds_bore [OPTIONS]"
      echo "Remove all .DS_Store files in the current directory and its subdirectories."
      echo
      echo "Options:"
      echo "  -h, --help  Show this help message and exit."
      echo "  -f, --files Show all .DS_Store files in the current directory and its subdirectories."
      echo "  No parameter: Delete them all"
      return 0
      ;;
    -f|--files)
      rg --files --hidden --glob '*.DS_Store'
      ;;
    *)
      rg --files --hidden --glob '*.DS_Store' | tee >(xargs -I{} rm "{}" >&2)
      ;;
  esac  
}

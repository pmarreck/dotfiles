# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
>/dev/null declare -F needs || \
needs() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin=$1
  shift
  command -v $bin >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

# Get the git status of all repos underneath $HOME
# As to why I decided to use "stati" instead of "statuses", see this:
# https://english.stackexchange.com/questions/877/what-is-the-plural-form-of-status
# Also because "octopi/octopii" is (arguably erroneously) accepted now, and it already
# breaks the same Latin (or Greek?) rule.
get_all_git_stati() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return;
  # needs rg "install ripgrep"; # rg is faster but keeps timing out and I don't know how to change its timeout
  needs fd "install fd-find" # you can easily rewrite this with the built-in 'find' if you must:
  # find . -maxdepth 10 -mindepth 0 -type d -exec sh -c '(cd "{}" && [ -d .git ] && echo "{}" && git diff --shortstat && echo)' 2>/dev/null \; || return 0

  local repo_dir git_dir
  fd '^\.git$' ~ --type d --hidden --threads 10 --prune --print0 | while IFS= read -r -d '' git_dir; do
    repo_dir="${git_dir%/.git/}"
    if git -C "$repo_dir" rev-parse --is-inside-work-tree &>/dev/null; then
      echo "$repo_dir"
      git -C "$repo_dir" diff --shortstat || echo "Failed to get git status for: $repo_dir"
      echo
    else
      echo "WARNING: Looks like a Git repository but is invalid: $repo_dir" >&2
    fi
  done
}
export -f get_all_git_stati

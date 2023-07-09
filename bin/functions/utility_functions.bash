# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
# >/dev/null declare -F needs || \
needs() {
  local bin=$1
  shift
  command -v "$bin" >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

source_relative_once assert.bash

# the following utility functions are duplicated from tinytestlib
save_shellenv() {
  export OLDHISTIGNORE=$HISTIGNORE
  export HISTIGNORE="shopt:set:eval"
  _prev_shell_opts=$(set +o; shopt -p;)
}

restore_shellenv() {
  eval "$_prev_shell_opts"
  # clean up after ourselves, don't want to pollute the ENV
  unset _prev_shell_opts
  export HISTIGNORE=$OLDHISTIGNORE
  unset OLDHISTIGNORE
}

# check if the AWK environment variable is already set and if not, set it to gawk or awk
[ -z "${AWK}" ] && export AWK=$(command -v gawk || command -v awk)

trim_leading_heredoc_whitespace() {
  # this expects heredoc contents to be piped in via stdin
  ${AWK:-awk} 'BEGIN { shortest = 99999 } /^[[:space:]]+/ { match($0, /[^[:space:]]/); shortest = shortest < RSTART - 1 ? shortest : RSTART - 1 } END { OFS=""; } { gsub("^" substr($0, 1, shortest), ""); print }' 
}

assert "$(echo -e "  This\n  is a\n  multiline\n  string." | trim_leading_heredoc_whitespace)" == "This\nis a\nmultiline\nstring."

collapse_whitespace_containing_newline_to_single_space() {
  # this expects contents to be piped in via stdin
  local sed=$(command -v gsed || command -v sed)
  [ "${PLATFORM}${sed}" == "osxsed" ] && echo "WARNING: function collapse_whitespace_containing_newline_to_single_space: The sed on PATH is not GNU sed on macOS, which may cause problems" >&2
  $sed -e ':a' -e 'N' -e '$!ba' -e 's/\s\n/ /g' -e 's/\n\s/ /g' -e 's/\s+/ /g'
}

assert "$(echo -e "This\nis a \nmultiline\n string." | collapse_whitespace_containing_newline_to_single_space)" == "This\nis a multiline string."

# Is this a color TTY? Or, is one (or the lack of one) being faked for testing reasons?
isacolortty() {
  [[ -v FAKE_COLORTTY ]] && return 0
  [[ -v FAKE_NOCOLORTTY ]] && return 1
  [[ "$TERM" =~ 'color' ]] && return 0 || return 1
}

# echo has nonstandard behavior, so...
puts() {
  local print_fmt end_fmt print_spec fd newline
  print_fmt=''
  print_spec='%s'
  newline='\n'
  end_fmt=''
  fd='1'
  while true; do
    case "${1}" in
      (--green)   print_fmt='\e[32m'; end_fmt='\e[0m' ;;
      (--yellow)  print_fmt='\e[93m'; end_fmt='\e[0m' ;;
      (--red)     print_fmt='\e[31m'; end_fmt='\e[0m' ;;
      (--stderr)  fd='2' ;;
      (-n)        newline='' ;;
      (-e)        print_spec='%b' ;;
      (-en|-ne)   print_spec='%b'; newline='' ;;
      (-E)        print_spec='%s' ;;
      (-*)        die "Unknown format specifier: ${1}" ;;
      (*)         break ;;
    esac
    shift
  done

  # If we're not interactive/color, override print_fmt and end_fmt to remove ansi
  isacolortty || unset -v print_fmt end_fmt

  # shellcheck disable=SC2059
  printf -- "${print_fmt}${print_spec}${end_fmt}${newline}" "${*}" >&$fd
}

# ANSI color helpers
red_text() {
  puts --red -en "$*"
}

green_text() {
  puts --green -en "$*"
}

yellow_text() {
  puts --yellow -en "$*"
}

# exit with red text to stderr, optional 2nd arg is error code
die() {
  red_text "${1}" >&2
  echo >&2
  exit ${2:-1}
}

# fail with red text to stderr, optional 2nd arg is return code
fail() {
  red_text "${1}" >&2
  echo >&2
  return ${2:-1}
}

strip_ansi() {
  local ansiregex="s/[\x1b\x9b]\[([0-9]{1,4}(;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]//g"
  # Take stdin if it's there; otherwise expect arguments.
  # The following exits code 0 if stdin not empty; 1 if empty; does not consume any bytes.
  # This may only be a Bash-ism, FYI. Not sure if it's shell-portable.
  if read -t 0; then # consume stdin
    sed -E "$ansiregex"
  else
    puts -en "${1}" | sed -E "$ansiregex"
  fi
}

# elixir and js lines of code count
# removes blank lines and commented-out lines
elixir_js_loc() {
  git ls-files | grep -E '\.erl|\.exs?|\.js$' | xargs cat | sed -e '/^$/d' -e '/^ *#/d' -e '/^ *\/\//d' | wc -l
}

# universal edit command, points back to your defined $EDITOR
# note that there is an "edit" command in Ubuntu that I told to fuck off basically
edit() {
  $EDITOR "$@"
}

# gem opener, if you have not yet moved on from Ruby to Elixir :)
open_gem() {
  $EDITOR "$(bundle show "$1")"
}

ltrim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  printf '%s' "$var"
}

rtrim() {
  local var="$*"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

trim() {
  local var="$*"
  var="$(ltrim "$var")"
  var="$(rtrim "$var")"
  printf '%s' "$var"
}

assert "$(ltrim "  foo  ")" == "foo  "
assert "$(rtrim "  foo  ")" == "  foo"
assert "$(trim "  foo  ")" == "foo"

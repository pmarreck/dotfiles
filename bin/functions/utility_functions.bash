# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
>/dev/null declare -F needs || \
needs() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin=$1
  shift
  command -v "$bin" >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  source_relative_once assert.bash
fi

# the following utility functions are duplicated from tinytestlib
save_shellenv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  export OLDHISTIGNORE=$HISTIGNORE
  export HISTIGNORE="shopt:set:eval"
  _prev_shell_opts=$(set +o; shopt -p;)
}

restore_shellenv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  eval "$_prev_shell_opts"
  # clean up after ourselves, don't want to pollute the ENV
  unset _prev_shell_opts
  export HISTIGNORE=$OLDHISTIGNORE
  unset OLDHISTIGNORE
}

# check if the AWK environment variable is already set and if not, set it to gawk or awk
[ -z "${AWK}" ] && export AWK=$(command -v gawk || command -v awk)

uniquify_array() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # ${AWK:-awk} '!seen[$0]++'
  # declare -n arr=$1  # indirect reference to the array name passed in as arg1
  # edit: forcing compatibility with bash < 4.2 (which doesn't support declare -n)
  # We can't use nameref, so use eval to indirectly reference the array
  eval 'arr=("${'"$1"'[@]}")'
  declare -A seen
  local unique_arr=()
  # Iterate over array elements, space-separated
  for value in "${arr[@]}"; do
    # Check if the value has been seen before
    if [[ -z "${seen[$value]}" ]]; then
      seen["$value"]=1
      unique_arr+=("$value")
    fi
  done
  # Assign unique values back to the original array using eval (grrr)
  eval "$1=(\"\${unique_arr[@]}\")"
}

function array_contains_element() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # declare -n array=$1
  # We can't use nameref, so use eval to indirectly reference the array
  eval 'array=("${'"$1"'[@]}")'
  element="$2"

  # Loop through the array and check if the element exists
  for item in "${array[@]}"; do
    if [[ "$item" == "$element" ]]; then
      # Element found in array, exit with 0
      return 0
    fi
  done

  # If we got here, the element was not found in the array, exit with 1
  return 1
}

move_PROMPT_COMMAND_to_precmd_functions() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # Replace newlines with semicolons
  PROMPT_COMMAND=${PROMPT_COMMAND//$'\n'/;}

  # Replace runs of 2 or more semicolons with one
  while [[ $PROMPT_COMMAND == *';;'* ]]; do
    PROMPT_COMMAND=${PROMPT_COMMAND//;;/;}
  done

  # Remove trailing semicolons
  PROMPT_COMMAND=${PROMPT_COMMAND%;}

  # Then split on semicolons
  IFS=';' read -ra commands <<< "$PROMPT_COMMAND"
  for cmd in "${commands[@]}"; do
    precmd_functions+=("$cmd")
  done

  # Then clear PROMPT_COMMAND
  PROMPT_COMMAND=''
}

# OK, thanks to badly written hooks, this now has to be a function
function rehash() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # Save state of hooks if they were already set up
  # echo "precmd_functions/PROMPT_COMMAND:"
  # declare -p PROMPT_COMMAND; declare -p precmd_functions
  # if [[ -v precmd_functions ]]; then
  #   local orig_precmd_functions
  #   orig_precmd_functions=("${precmd_functions[@]}")
  #   echo "we saved precmd_functions"
  # fi
  # if [[ -v PROMPT_COMMAND ]]; then
  #   local orig_PROMPT_COMMAND
  #   orig_PROMPT_COMMAND=("${PROMPT_COMMAND[@]}")
  #   echo "we saved PROMPT_COMMAND"
  # fi
  unset _SOURCED_FILES
  source $HOME/.bashrc
  # I had to set this declaratively to what it's set in a new terminal to avoid brittle behavior
  # declare -- PROMPT_COMMAND=$'mcfly_prompt_command;_direnv_hook\n__bp_trap_string="$(trap -p DEBUG)"\ntrap - DEBUG\n__bp_install'
  # declare -a precmd_functions=([0]="starship_precmd")
  # declare -a preexec_functions=([0]="starship_preexec_all")
  declare -a PROMPT_COMMAND=([0]=$'__bp_precmd_invoke_cmd\nmcfly_prompt_command;_direnv_hook\n:' [1]="__bp_interactive_mode")
  declare -a precmd_functions=([0]="starship_precmd" [1]="precmd")
  declare -a preexec_functions=([0]="starship_preexec_all" [1]="preexec")
  # echo "precmd_functions/PROMPT_COMMAND after bashrc:"
  # declare -p PROMPT_COMMAND; declare -p precmd_functions
  # # Restore hook setup
  # if [[ -v orig_precmd_functions ]]; then
  #   echo "we are restoring original precmd_functions"
  #   precmd_functions=(${orig_precmd_functions[*]})
  #   echo "precmd_functions/PROMPT_COMMAND after restoration:"
  #   declare -p PROMPT_COMMAND; declare -p precmd_functions
  #   # The dumb hook code inserts dupes sometimes if they are rerun (not idempotent),
  #   # so we have to do this:
  #   # (I hate how mutable this looks but it was the easiest way.
  #   # Reassigning arrays in Bash is a nightmare.)
  #   uniquify_array precmd_functions
  #   echo "precmd_functions/PROMPT_COMMAND after uniquifying:"
  #   declare -p PROMPT_COMMAND; declare -p precmd_functions
  # fi
  # if [[ -v orig_PROMPT_COMMAND ]]; then
  #   echo "we are restoring original PROMPT_COMMAND"
  #   PROMPT_COMMAND=(${orig_PROMPT_COMMAND[*]})
  #   declare -p PROMPT_COMMAND; declare -p precmd_functions
  #   # Do not need to uniquify this one at this time.
  # fi
}

# This function emits an OSC 7 sequence to inform the terminal
# of the current working directory.  It prefers to use a helper
# command provided by wezterm if wezterm is installed, but falls
# back to a simple printf command otherwise.
__wezterm_osc7() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local default_directory=${1:-$PWD}
  if hash wezterm 2>/dev/null ; then
    wezterm set-working-directory $default_directory 2>/dev/null && return 0
    # If the command failed (perhaps the installed wezterm
    # is too old?) then fall back to the simple version below.
  fi
  printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "${default_directory}"
}

__wezterm_osc7_home() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  __wezterm_osc7 "$HOME"
}

trim_leading_heredoc_whitespace() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # this expects heredoc contents to be piped in via stdin
  ${AWK:-awk} 'BEGIN { shortest = 99999 } /^[[:space:]]+/ { match($0, /[^[:space:]]/); shortest = shortest < RSTART - 1 ? shortest : RSTART - 1 } END { OFS=""; } { gsub("^" substr($0, 1, shortest), ""); print }'
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  assert "$(echo -e "  This\n  is a\n  multiline\n  string." | trim_leading_heredoc_whitespace)" == "This\nis a\nmultiline\nstring."
fi

collapse_whitespace_containing_newline_to_single_space() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # this expects contents to be piped in via stdin
  local sed=$(command -v gsed || command -v sed)
  [ "${PLATFORM}${sed}" == "osxsed" ] && echo "WARNING: function collapse_whitespace_containing_newline_to_single_space: The sed on PATH is not GNU sed on macOS, which may cause problems" >&2
  $sed -e ':a' -e 'N' -e '$!ba' -e 's/\s\n/ /g' -e 's/\n\s/ /g' -e 's/\s+/ /g'
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  assert "$(echo -e "This\nis a \nmultiline\n string." | collapse_whitespace_containing_newline_to_single_space)" == "This\nis a multiline string."
fi

# Is this a color TTY? Or, is one (or the lack of one) being faked for testing reasons?
isacolortty() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  [[ -n "${FAKE_COLORTTY}" ]] && return 0
  [[ -n "${FAKE_NOCOLORTTY}" ]] && return 1
  [[ "$TERM" =~ 'color' ]] && return 0 || return 1
}

# echo has nonstandard behavior, so...
puts() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
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
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  puts --red -en "$*"
}

green_text() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  puts --green -en "$*"
}

yellow_text() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  puts --yellow -en "$*"
}

echo_command() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  yellow_text "$*\n" >&2
  eval "$*"
}

# exit with red text to stderr, optional 2nd arg is error code
die() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  red_text "${1}" >&2
  echo >&2
  exit ${2:-1}
}

# fail with red text to stderr, optional 2nd arg is return code
fail() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  red_text "${1}" >&2
  echo >&2
  return ${2:-1}
}

strip_ansi() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
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
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  git ls-files | grep -E '\.erl|\.exs?|\.js$' | xargs cat | sed -e '/^$/d' -e '/^ *#/d' -e '/^ *\/\//d' | wc -l
}

contains() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local word
  for word in $1; do
    if [[ "$word" == "$2" ]]; then
      return 0
    fi
  done
  return 1
}
# universal edit command, points back to your defined $EDITOR
# note that there is an "edit" command in Ubuntu that I told to fuck off basically
edit() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if contains "$(functions)" $1; then
    EDIT=1 $1
  else
    choose_editor "$@"
  fi
}

# gem opener, if you have not yet moved on from Ruby to Elixir :)
open_gem() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  choose_editor "$(bundle show "$1")"
}

ltrim() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  printf '%s' "$var"
}

rtrim() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local var="$*"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

trim() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local var="$*"
  var="$(ltrim "$var")"
  var="$(rtrim "$var")"
  printf '%s' "$var"
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  assert "$(ltrim "  foo  ")" == "foo  "
  assert "$(rtrim "  foo  ")" == "  foo"
  assert "$(trim "  foo  ")" == "foo"
fi

image_convert_to_heif() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # base name of argument 1
  # local bn="${1%.*}"
  # ffmpeg -i "$1" -c:v libx265 -preset ultrafast -x265-params lossless=1 "${bn}.heif"

  # lossless conversion, FYI
  needs heif-enc "please install libheif" && \
  echo_command "heif-enc -L -p chroma=444 --matrix_coefficients=0 \"$1\""
}

image_convert_to_jpegxl() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # base name of argument 1
  local bn="${1%.*}"
  local d="${JXL_DISTANCE:-0}" # 0-9 where 0 is lossless; default 0
  local e="${JXL_EFFORT:-7}" # 0-9 where 9 is extremely slow but smallest; default 7

  needs cjxl "please install the libjxl package to get the cjxl executable" && \
  echo_command "cjxl -d $d -e $e --lossless_jpeg=0 \"$1\" \"${bn}.jxl\""
}

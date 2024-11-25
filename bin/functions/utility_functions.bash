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

# check if the AWK environment variable is already set and if not, set it to frawk, gawk, or awk
[ -z "${AWK}" ] && export AWK=$(command -v frawk || command -v gawk || command -v awk)

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

array_contains_element() {
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
  #  echo "Debug: Function started" >&2
  # For some reason, frawk screws this up. No time to troubleshoot.
  needs gawk "please install gawk (GNU awk) to run this function" && \
  gawk '
  BEGIN { shortest = -1 }
  {
    lines[NR] = $0
    #  print "Debug: Processing line: [" $0 "]" > "/dev/stderr"
    #  print "Debug: Line length: " length($0) > "/dev/stderr"
    match($0, /[^[:space:]]/);
    #  print "Debug: RSTART = " RSTART > "/dev/stderr"
    if (RSTART > 0) {
      if (shortest == -1 || RSTART - 1 < shortest) {
        shortest = RSTART - 1
      #  print "Debug: shortest updated to " shortest > "/dev/stderr"
    }
  } else {
    #  print "Debug: No match found in this line" > "/dev/stderr"
  }
}
END {
  #  print "Debug: END block reached, shortest = " shortest > "/dev/stderr"
  if (shortest >= 0) {
    for (i=1; i<=NR; i++) {
      if (length(lines[i]) > shortest) {
        print substr(lines[i], shortest + 1)
      } else {
        print ""
      }
    }
  } else {
    #  print "Debug: No processing done (shortest < 0)" > "/dev/stderr"
  }
}
'
#  echo "Debug: Function ended" >&2
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  assert "$(echo -e "  This\n  is a\n    multiline\n  string." | trim_leading_heredoc_whitespace)" == "This\nis a\n  multiline\nstring."
fi

# The point of this function is to unwrap word-wrapped (which should
# really be called "line-wrapped") text that has had newlines inserted,
# but leave intentional newlines (those without surrounding whitespace)
# alone.
unwrap() {
  local SED=`which sed`
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # this expects contents to be piped in via stdin
  [[ "$(sed --version | head -1)" =~ .*GNU.* ]] || echo "WARNING: function unwrap: The sed on PATH is not GNU sed, which may cause problems" >&2 && SED="/run/current-system/sw/bin/sed"
  # sed -E -e ':a;N;$!ba' -e 's/( \n | \n|\n )/ /g'
  $SED -E ':a;N;$!ba;s/( +\n +| *\n +| +\n *)/ /g'
}

# Wraps text to the current width of the terminal, or to a specified width.
# Expects input via stdin
# For already-wrapped text, consider using unwrap first
wrap() {
  # take an argument of colwidth but default to current terminal width
  local colwidth=${1:-$(tput cols)}
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # this expects contents to be piped in via stdin
  fold -s -w $colwidth
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  # test unwrap
  assert "$(echo -e "This\nis a \nmultiline\n string." | unwrap)" == "This\nis a multiline string."
  # test unwrap preserving double newlines
  assert "$(echo -e "This\nis a\n\nmultiline\n string." | unwrap)" == "This\nis a\n\nmultiline string."
  # test wrap
  assert "$(echo -e "This is a long line that should be wrapped to width 16." | wrap 16)" == "This is a long \nline that \nshould be \nwrapped to \nwidth 16."
fi

# Is this a color TTY? Or, is one (or the lack of one) being faked for testing reasons?
isacolortty() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  [[ "$TERM" =~ 'color' ]] && return 0 || return 1
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  TERM=xterm-256color isacolortty
  assert "$?" == "0"
  TERM=dumb isacolortty
  assert "$?" == "1"
fi

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

echo_eval() {
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
  local ansiregex="s/\x1b\[[0-9;]*[a-zA-Z]//g"

  if [ -t 0 ] && [ "$#" -eq 0 ]; then
    printf "Usage: strip_ansi [text]\n"
    printf "   or: printf '%%s' text | strip_ansi\n"
    return 1
  fi

  if [ -t 0 ]; then
    # Input from arguments
    printf '%b' "$*" | $SED -E "$ansiregex"
  else
    # Input from pipe
    $SED -E "$ansiregex"
  fi
}

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  assert "$(printf '\e[31mRed text\e[0m' | strip_ansi)" == "Red text"
  assert "$(strip_ansi '\e[93mYellow text\e[0m')" == "Yellow text"
fi

# elixir and js lines of code count
# removes blank lines and commented-out lines
elixir_js_loc() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  git ls-files | grep -E '\.erl|\.exs?|\.js$' | xargs cat | $SED -e '/^$/d' -e '/^ *#/d' -e '/^ *\/\//d' | wc -l
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

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  contains "foo bar baz" "bar"
  assert "$?" == "0"
  contains "foo bar" "quux"
  assert "$?" == "1"
fi

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

datetime() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  date "+%Y-%m-%d %H:%M:%S"
}

datetime-human() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  date +"%A, %B %d, %Y %I:%M %p"
}

image_convert_to_heif() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # base name of argument 1
  # local bn="${1%.*}"
  # ffmpeg -i "$1" -c:v libx265 -preset ultrafast -x265-params lossless=1 "${bn}.heif"

  # lossless conversion, FYI
  needs heif-enc "please install libheif" && \
  echo_eval "heif-enc -L -p chroma=444 --matrix_coefficients=0 \"$1\""
}

image_convert_to_jpegxl() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # base name of argument 1
  local bn="${1%.*}"
  local d="${JXL_DISTANCE:-0}" # 0-9 where 0 is lossless; default 0
  local e="${JXL_EFFORT:-7}" # 0-9 where 9 is extremely slow but smallest; default 7

  needs cjxl "please install the libjxl package to get the cjxl executable" && \
  echo_eval "cjxl -d $d -e $e --lossless_jpeg=0 \"$1\" \"${bn}.jxl\""
}

# supertop: open htop and btop at the same time in a tmux split
# requires btop and htop to be installed
supertop() {
  # Check if btop++ is installed
  if ! command -v nix &> /dev/null; then
    echo "nix is not installed. Please install it first, along with btop and htop."
    return
  fi

  # randomize the name of split_session by adding the shell pid
  local session_name
  session_name="split_session_$$"

  # Start a new tmux session with two vertical panes
  tmux new-session -d -s ${session_name}  # Create a new detached session named 'split_session_$$'

  # Run htop in the first pane
  tmux send-keys -t ${session_name}:0 'htop' C-m

  # Split the window horizontally and run btop++ in the second pane
  tmux split-window -h  # Split the window horizontally
  tmux send-keys -t ${session_name}:0.1 'btop' C-m

  # Attach to the session
  tmux attach-session -t ${session_name}  # Attach to the created session
}
alias t='supertop'

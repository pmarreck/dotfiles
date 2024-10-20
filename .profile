#!/bin/sh
# .profile must remain POSIX-compliant, use shellcheck to verify
# There is currently 1 exception to this rule: the use of ${BASH_SOURCE[0]} in source_relative[_once]

[ -n "$DEBUG_SHELLCONFIG" ] && echo "Entering $(echo "${BASH_SOURCE[0]}" | sed "s|^$HOME|~|")" || printf "#"
[ -n "$DEBUG_PATHCONFIG" ] && echo $PATH

$INTERACTIVE_SHELL && echo " $DISTRO_PRETTY"

# most things should be sourced via source_relative... except source_relative itself
source $HOME/dotfiles/bin/functions/source_relative.bash

source_relative_once bin/functions/truthy.bash

# The only functions defined here should be the ones that are needed everywhere
# and are not specific to a particular shell (e.g. bash, zsh, etc.)

source_relative_once bin/functions/utility_functions.bash
source_relative_once bin/functions/binhex.bash

# config for Visual Studio Code
# if [ "$PLATFORM" = "osx" ]; then
#   code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode --args "$*" ;}
#   pipeable_code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode -f ;}
#   export PIPEABLE_EDITOR='pipeable_code'
# fi
# export EDITOR='code' # already set in .bashrc

# set default tab stops to 2 spaces
# Note that this may mess up ncurses code that might assume 8 spaces
tabs -2

# If you hate noise
# set bell-style visible

# ulimit. to see all configs, run `ulimit -a`
# ulimit -n 10000

source_relative_once bin/aliases.sh

# Linux-specific stuff
if [ "${PLATFORM}" = "linux" ]; then
  source_relative_once bin/functions/fsattr.bash
  # provide a universal "open" on linux to open a path in the file manager
  open() {
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    # if no args, open current dir
    xdg-open "${1:-.}"
  }
  # list network interface names. Why is this so hard on linux?
  list-nics() {
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    # ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//'
    # the above was missing altnames.
    # this is a bit hacky but there are many ways to skin this cat
    ip link show | $AWK '{print $2}' | sed 's/://' | grep -E '^(lo|en|wl)'
  }
  # list processes with optional filter argument
  list-procs() {
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    PS_PERSONALITY=linux ps -ewwo pid,%cpu,%mem,nice,pri,rtprio,args --sort=-pcpu,-pid | $AWK -v filter="$1" 'NR==1 || tolower($0) ~ tolower(filter)' | less -e --header=1
  }
  alias procs=list-procs
  source_relative_once bin/functions/nvidia.bash
fi

source_relative_once bin/functions/get_all_git_stati.sh

source_relative_once bin/functions/compsavings.bash

# because I always forget how to do this...
dd_example() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  echo "sudo dd if=/home/pmarreck/Downloads/TrueNAS-SCALE-22.02.4.iso of=/dev/sdf bs=1M oflag=sync status=progress"
}

# make it easier to write ISO's to a USB key:
write_iso() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  sudo dd if="$1" of="$2" bs=1M oflag=sync status=progress
}

source_relative_once bin/functions/cpv_copy_verbose.sh

source_relative_once bin/functions/date_difference_days.bash

source_relative_once bin/functions/calc.bash

source_relative_once bin/functions/encrypt_decrypt.sh

source_relative_once bin/functions/randompass.sh

source_relative_once bin/functions/executables.bash

# which hack, so it also shows defined aliases and functions that match
# where() {
#   type_out=`type "$@"`;
#   if [ ! -z "$type_out" ]; then
#     echo "$type_out";
#   else
#     /usr/bin/env which $@;
#   fi
# }
# Note: Superseded by "show" function below

source_relative_once bin/functions/show.sh
alias d=show # "view" goes to vim, "s" usually launches a search or server, so "d" (for "define") is a good alias for show IMHO

source_relative_once bin/functions/dragon.sh

source_relative_once bin/functions/ds_bore.sh

source_relative_once bin/functions/warhammer_quote.bash

source_relative_once bin/functions/bashorg_quote.bash

source_relative_once bin/functions/mandelbrot.sh

source_relative_once bin/functions/clock.bash

source_relative_once bin/functions/weather.bash

source_relative_once bin/functions/please.bash

source_relative_once bin/functions/grandfather_clock_chime.sh

source_relative_once bin/ask

# crypto market data. can pass a symbol in or just get the current overall market data
crypto() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  curl rate.sx/$1
}

# am I the only one who constantly forgets the correct order of arguments to `ln`?
lnwtf() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  echo 'ln -s path_of_thing_to_link_to [name_of_link]'
  echo '(If you omit the latter, it puts a basename-named link in the current directory)'
  echo "This function is defined in $0"
}

up() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  uptime | $AWK '{split($0,a,"  up ");split(a[2],b,", ");print"["b[1]", "b[2]"]"}'
}

# browse a CSV file as a scrollable table
csv() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs column
  if [ -e "$1" ]; then
    column -s, -t < "$1" | less -#2 -N -S --header 1
  else
    echo "File argument nonexistent or file not found" >&2
  fi
}

source_relative_once bin/functions/otp_version.sh

source_relative_once bin/functions/pman_nice_man_pages.sh

source_relative_once bin/functions/portopen_fileopen.sh

source_relative_once bin/functions/print_x_times.sh

# only enable this on arch somehow
# source ~/bin/pac

# git functions
#$PIPEABLE_EDITOR;
# gd() {
#   git diff ${1} | subl ;
# }

# function rbr {
#  git checkout $1;
#  git pull origin $1;
#  git checkout $2;
#  git rebase $1;
# }

# function mbr {
#  git checkout $1;
#  git merge $2
#  git push origin $1;
#  git checkout $2;
# }

# the following depend on the parse_git_branch function defined elsewhere
# function rebase_to_latest_master {
#   cur=$(parse_git_branch);
#   git stash;
#   git checkout master;
#   git pull origin master;
#   git checkout $cur;
#   git rebase master;
#   git stash pop;
# }

# 'git pull origin master' shortcut, but make sure you're on master first!
# function gpom {
#   cur=$(parse_git_branch);
#   if [ $cur = 'master' ]; then
#     git pull origin master;
#   else
#     echo "DUDE! You aren't on master branch!"
#   fi
# }

# function open_all_files_changed_from_master {
#   if [ -d .git ]; then
#     $EDITOR .
#     for file in `git diff --name-only master`
#     do
#       $EDITOR $file
#     done
#   else
#     echo "Hey man. You're not in a directory with a git repo."
#   fi
# }

# automated git bisecting. because I hate remembering how to use this.
# ex. usage: git_wtf_happened <ruby testfile> <how many commits back, default 8>
# function git_wtf_happened {
#   git bisect start HEAD HEAD~${2:-8};
#   shift;
#   git bisect run $1;
#   git bisect view;
#   git bisect reset;
# }

source_relative_once bin/functions/pg_postgres_wrapper.sh

source_relative_once bin/functions/notify.sh

source_relative_once bin/functions/ff_fast_find.sh

source_relative_once bin/functions/git_commit_ai.bash

source_relative_once bin/functions/Time.now.to_f.sh

source_relative_once bin/functions/note_time_diff.sh

source_relative_once bin/functions/div.sh

source_relative_once bin/functions/flip_a_coin.sh

source_relative_once bin/functions/roll_a_die.sh

source_relative_once bin/functions/repeat_command.bash

source_relative_once bin/functions/uuidv7.sh

source_relative_once bin/functions/kill-steam-proton-pids.bash

source_relative_once bin/functions/whatismyip.sh

# command prompt
# NOTE: Now configured via starship in apply-hooks
# $INTERACTIVE_SHELL && . $HOME/.commandpromptconfig

# Pull in path configuration AGAIN because macos keeps mangling it
# (also did it in .bashrc)
source_relative_once .pathconfig

# silliness

# chuck norris quotes
chuck() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # if you want to filter out the obscene ones, there's a category you can filter out,
  # but it didn't get all of them... you can also pipe to glow for a nicer output
  # figure out the path of the current script
  local SCRIPT_PATH=$(dirname "$(readlink -f "$BASH_SOURCE")")
  shuf -n 1 "$SCRIPT_PATH/bin/chuck_norris.txt" | cut -d'|' -f2- | wrap
}

inthebeginning() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs magick please install imagemagick && magick "$HOME/inthebeginning.jpg" -geometry 400x240 sixel:-
}

just_one_taoup() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # ChatGPT4 wrote 99% of this. I preserved the conversation with it about it: https://gist.github.com/pmarreck/339fb955a74caed692b439038c9c1c9d
  # needs taoup please install taoup && taoup \
  # Refresh the taoup.ansi file occasionally via taoup > taoup.ansi. Last updated 2024-10-12.
  # Caching it this way avoids needing either taoup OR ruby and saves on ruby processing.
  $AWK -v seed=`date +%N` '
    BEGIN{
      srand(seed)
    }
    /^-{3,}/{
      header=$0; next
    }
    !/^$/{
      lines[count++]=$0;
      headers[count-1]=header;
    }
    END{
      randIndex=int(rand()*count);
      print headers[randIndex];
      print lines[randIndex];
    }
  ' $HOME/dotfiles/bin/taoup.ansi
}

source_relative_once bin/times_older_than

times_older_than_samson() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  echo "Peter, you are $(times_older_than "1972-04-05" "2021-06-25") times older than Samson."
}


check_sixel_support() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # Check if the terminal supports Sixel via infocmp
  if infocmp -1 | grep -q "sixel"; then
    [ -n "$DEBUG_SHELLCONFIG" ] && echo "Sixel support detected via terminfo." >&2
    return 0
  fi
  # Check specific terminals that might not report via infocmp
  if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
    [ -n "$DEBUG_SHELLCONFIG" ] && echo "WezTerm detected, which supports Sixel." >&2
    return 0
  fi
  if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
    [ -n "$DEBUG_SHELLCONFIG" ] && echo "Apple Terminal detected, which does not support Sixel." >&2
    return 1
  fi
  if [[ "$WSLENV" ]]; then
    [ -n "$DEBUG_SHELLCONFIG" ] && echo "WSL detected. Sixel support depends on the Windows terminal used." >&2
    return 2
  fi
  if [[ "$ALACRITTY_LOG" || "$ALACRITTY_WINDOW_ID" ]]; then
    [ -n "$DEBUG_SHELLCONFIG" ] && echo "Alacritty detected, which does not support Sixel as of 2024." >&2
    return 1
  fi
  if [[ "$TERM" == "xterm-256color" ]]; then
    parent_process=$(ps -p $PPID -o comm=)
    if [[ "$parent_process" == *"cool-retro-term"* ]]; then
      [ -n "$DEBUG_SHELLCONFIG" ] && echo "cool-retro-term detected, which does not support Sixel." >&2
      return 1
    fi
  fi
  if [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; then
    [ -n "$DEBUG_SHELLCONFIG" ] && echo "Warp terminal detected, which does not support Sixel as of 2024." >&2
    return 1
  fi
  # Fall back on the assumption that these might work
  case "$TERM" in
    xterm-256color|xterm-kitty|mlterm|yaft|wezterm)
      [ -n "$DEBUG_SHELLCONFIG" ] && echo "Terminal ($TERM) likely supports Sixel graphics." >&2
      return 0
      ;;
  esac
  echo "Unable to determine Sixel support. Terminal: $TERM, TERM_PROGRAM: $TERM_PROGRAM" >&2
  return 2
}
SIXEL_ENV=$(DEBUG_SHELLCONFIG=1 check_sixel_support 2>&1)
SIXEL_CAPABLE=$?
# if retcode is 0 then set SIXEL_CAPABLE to "true" else "false"
if [ "$SIXEL_CAPABLE" -eq 0 ]; then
  SIXEL_CAPABLE="true"
else
  SIXEL_CAPABLE="false"
fi
export SIXEL_ENV SIXEL_CAPABLE

if [ "$INTERACTIVE_SHELL" = "true" ]; then
  fun_intro() {
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    sixel_less="fortune warhammer_quote bashorg_quote chuck mandelbrot asciidragon just_one_taoup times_older_than_samson"
    # This one requires a Sixel-capable terminal
    sixel_ful="inthebeginning"
    if ! $SIXEL_CAPABLE; then
      _fun_things="$sixel_less"
    else
      _fun_things="$sixel_less $sixel_ful"
    fi
    _selected_fun_thing=$(echo "$_fun_things" | tr ' ' '\n' | shuf -n 1)

    if command -v "$_selected_fun_thing" >/dev/null 2>&1; then
      eval "$_selected_fun_thing"
    else
      echo "Tried to call '$_selected_fun_thing', but it was not defined" >&2
    fi
    unset _fun_things sixel_less sixel_ful _selected_fun_thing
  }
  fun_intro
fi

[ -n "$DEBUG_SHELLCONFIG" ] && echo "Exiting $(echo "${BASH_SOURCE[0]}" | sed "s|^$HOME|~|")"
[ -n "$DEBUG_PATHCONFIG" ] && echo $PATH || :

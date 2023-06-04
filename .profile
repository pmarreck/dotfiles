#!/bin/sh
# .profile must remain POSIX-compliant, use shellcheck to verify
# There is currently 1 exception to this rule: the use of ${BASH_SOURCE[0]} in source_relative[_once]

$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo "Running .profile" || printf "#"

$INTERACTIVE_SHELL && echo " Platform: $PLATFORM"

# The only functions defined here should be the ones that are needed everywhere
# and are not specific to a particular shell (e.g. bash, zsh, etc.)

# source a file relative to the current file
source_relative() {
  # _dir_name=`dirname "$0"` # doesn't work reliably
  _dir_name=`dirname "${BASH_SOURCE[0]}"` # works in bash but not POSIX compliant sh
  _temp_path=`cd "$_dir_name" && pwd`
  # $_TRACE_SOURCING && echo "Sourcing $temp_path/$1" >&2
  . "$_temp_path/$1"
  unset _dir_name _temp_path
}

# Define the source_relative_once function
source_relative_once() {
  _file="$1"
  # Get the directory of the currently executing script
  # _dir=`dirname "$0"` # doesn't work reliably
  _dir=`dirname "${BASH_SOURCE[0]}"` # works in bash but not POSIX compliant sh
  
  # Convert the relative path to an absolute path
  _abs_path="$_dir/$_file"
  _abs_dirname=`dirname "$_abs_path"`
  _abs_dirname=`cd "$_abs_dirname" && pwd`
  _abs_filename=`basename "$_abs_path"`
  _abs_path="$_abs_dirname/$_abs_filename"

  if [ ! -e "$_abs_path" ]; then
    echo "Error in source_relative_once: could not find file $_abs_path" >&2
    return
  fi

  # Check if the file has already been sourced
  if echo " ${_sourced_files} " | grep -q " ${_abs_path} "; then
    # $_TRACE_SOURCING && echo "Already sourced $abs_path" >&2
    return
  fi
  # $_TRACE_SOURCING && _debug_id=$RANDOM
  # If the file hasn't been sourced yet, source it and add it to the list of sourced files
  # $_TRACE_SOURCING && echo "$_debug_id Sourcing (once?) $abs_path" >&2
  # $_TRACE_SOURCING && echo "$_debug_id prior to sourcing, _sourced_files is now ${_sourced_files}" >&2
  . "$_abs_path" && _sourced_files="$_sourced_files $_abs_path"
  # $_TRACE_SOURCING && echo "$_debug_id _sourced_files is now ${_sourced_files}" >&2
  unset _file _dir _abs_path
  # $_TRACE_SOURCING && unset _debug_id
}

source_relative_once bin/functions/utility_functions.bash
source_relative_once bin/functions/binhex.bash

# config for Visual Studio Code
if [ "$PLATFORM" = "osx" ]; then
  code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode --args "$*" ;}
  pipeable_code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode -f ;}
  export PIPEABLE_EDITOR='pipeable_code'
fi
# export EDITOR='code' # already set in .bashrc

# If you hate noise
# set bell-style visible

# Pager config (ex., for git diff output)
#E=quit at first EOF
#Q=no bell
#R=pass through raw ansi so colors work
#X=no termcap init
export LESS="-EQRX"

# ulimit. to see all configs, run `ulimit -a`
# ulimit -n 10000

source_relative_once bin/aliases.sh

# Linux-specific stuff
if [ "${PLATFORM}" = "linux" ]; then
  source_relative_once bin/functions/fsattr.bash
  # provide a universal "open" on linux to open a path in the file manager
  open() {
    # if no args, open current dir
    xdg-open "${1:-.}"
  }
  # list network interface names. Why is this so hard on linux?
  list-nics() {
    # ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//'
    # the above was missing altnames.
    # this is a bit hacky but there are many ways to skin this cat
    ip link show | $AWK '{print $2}' | sed 's/://' | grep -E '^(lo|en|wl)'
  }
  # list processes with optional filter argument
  list-procs() {
    PS_PERSONALITY=linux ps -ewwo pid,%cpu,%mem,nice,pri,rtprio,args --sort=-pcpu,-pid | awk -v filter="$1" 'NR==1 || tolower($0) ~ tolower(filter)' | less -e --header=1
  }
  alias procs=list-procs
fi

source_relative_once bin/functions/nvidia.bash

source_relative_once bin/functions/get_all_git_stati.sh

source_relative_once bin/functions/compsavings.bash

# because I always forget how to do this...
dd_example() {
  echo "sudo dd if=/home/pmarreck/Downloads/TrueNAS-SCALE-22.02.4.iso of=/dev/sdf bs=1M oflag=sync status=progress"
}

# make it easier to write ISO's to a USB key:
write_iso() {
  sudo dd if="$1" of="$2" bs=1M oflag=sync status=progress
}

source_relative_once bin/functions/cpv_copy_verbose.sh

source_relative_once bin/functions/calc.bash

source_relative_once bin/functions/encrypt_decrypt.sh

source_relative_once bin/functions/randompass.sh

# GPG configuration to set up in-terminal challenge-response
export GPG_TTY=`tty`

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

source_relative_once bin/functions/datetimestamp.bash

source_relative_once bin/functions/show.sh
alias v=show # "view" goes to vim, "s" usually launches a search or server, so "v" is a good alias for show IMHO

source_relative_once bin/functions/dragon.sh

source_relative_once bin/functions/warhammer_quote.bash

source_relative_once bin/functions/ask.sh

source_relative_once bin/functions/mandelbrot.sh

source_relative_once bin/functions/clock.bash

source_relative_once bin/functions/weather.bash

source_relative_once bin/functions/list_all_executables_on_PATH.sh

source_relative_once bin/functions/please.bash

# crypto market data. can pass a symbol in or just get the current overall market data
crypto() {
  curl rate.sx/$1
}

# am I the only one who constantly forgets the correct order of arguments to `ln`?
lnwtf() {
  echo 'ln -s path_of_thing_to_link_to [name_of_link]'
  echo '(If you omit the latter, it puts a basename-named link in the current directory)'
  echo "This function is defined in $0"
}

up() {
  uptime | $AWK '{split($0,a,"  up ");split(a[2],b,", ");print"["b[1]", "b[2]"]"}'
}

# browse a CSV file as a scrollable table
csv() {
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

# git functions and extra config
source_relative_once bin/functions/git-branch.bash # defines parse_git_branch and parse_git_branch_with_dirty
source_relative_once bin/functions/git-completion.bash

source_relative_once bin/functions/notify.sh

source_relative_once bin/functions/ff_fast_find.sh

source_relative_once bin/functions/git_commit_ai.bash

source_relative_once bin/functions/Time.now.to_f.sh

source_relative_once bin/functions/note_time_diff.sh

source_relative_once bin/functions/div.sh

source_relative_once bin/functions/flip_a_coin.sh

source_relative_once bin/functions/roll_a_die.sh

source_relative_once bin/functions/repeat_command.bash

# command prompt
$INTERACTIVE_SHELL && . $HOME/.commandpromptconfig

# Pull in path configuration AGAIN because macos keeps mangling it
# (also did it in .bashrc)
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo "from $0: "
. $HOME/.pathconfig

# silliness

inthebeginning() {
  needs convert please install imagemagick && convert "$HOME/inthebeginning.jpg" -geometry 400x240 sixel:-
}

just_one_taoup() {
  # ChatGPT4 wrote 99% of this. I preserved the conversation with it about it: https://gist.github.com/pmarreck/339fb955a74caed692b439038c9c1c9d
  needs taoup please install taoup && \
  taoup | $AWK -v seed=`date +%N` 'BEGIN{srand(seed)} /^-{3,}/{header=$0; next} !/^$/{lines[count++]=$0; headers[count-1]=header} END{randIndex=int(rand()*count); print headers[randIndex]; print lines[randIndex]}'
}

if [ "$INTERACTIVE_SHELL" = "true" ]; then
  fun_intro() {
    _fun_things="fortune inthebeginning warhammer_quote chuck mandelbrot asciidragon just_one_taoup"
    _count=0
    for _item in $_fun_things; do
      _count=$(( _count + 1 ))
    done

    _random_seed=`date +%N`
    _random_number=`$AWK -v seed="$_random_seed" 'BEGIN { srand(seed); print int(rand() * 32768) }'`
    _idx=$(( _random_number % _count ))

    _current_idx=0
    _selected_fun_thing=""
    for _item in $_fun_things; do
      if [ $_current_idx -eq $_idx ]; then
        _selected_fun_thing="$_item"
        break
      fi
      _current_idx=$(( _current_idx + 1 ))
    done

    if command -v "$_selected_fun_thing" >/dev/null 2>&1; then
      eval "$_selected_fun_thing"
    else
      echo "Tried to call '$_selected_fun_thing', but it was not defined" >&2
    fi
    unset _fun_things _count _random_seed _random_number _idx _current_idx _selected_fun_thing _item
  }
  fun_intro
fi

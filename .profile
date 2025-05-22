#!/bin/sh
# .profile must remain POSIX-compliant, use shellcheck to verify
# There is currently 1 exception to this rule: the use of ${BASH_SOURCE[0]} for debugging
truthy DEBUG_SHELLCONFIG && echo "Entering $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")" || $INTERACTIVE_SHELL && $LOGIN_SHELL && append_dotfile_progress "prof"
truthy DEBUG_PATHCONFIG && echo $PATH

$INTERACTIVE_SHELL && $LOGIN_SHELL && echo "$DISTRO_PRETTY"

# most things should be sourced via source_relative... except source_relative itself
# if the function is not already defined, define it. use posix syntax for portability
# shellcheck disable=SC1090
# [ -n "$DEBUG_SHELLCONFIG" ] && ! [ "`type -t source_relative_once`" = "function" ] && echo "sourced source_relative.bash"
# truthy is now an executable in $HOME/dotfiles/bin
# The only functions defined here should be the ones that are needed everywhere
# and are not specific to a particular shell (e.g. bash, zsh, etc.)

# binhex is now an executable in $HOME/dotfiles/bin

# [ -n "$DEBUG_SHELLCONFIG" ] && echo "sourced nix-hash-retrievals.bash"

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
# [ -n "$DEBUG_SHELLCONFIG" ] && echo "set tabs to 2 spaces"

# If you hate noise
# set bell-style visible

# ulimit. to see all configs, run `ulimit -a`
# ulimit -n 10000

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

# command prompt
# NOTE: Now configured via starship in apply-hooks
# $INTERACTIVE_SHELL && . $HOME/.commandpromptconfig

# Pull in path configuration AGAIN because macos keeps mangling it
# (also did it in .bashrc)
. $HOME/.pathconfig
# [ -n "$DEBUG_SHELLCONFIG" ] && echo "sourced .pathconfig"

SIXEL_ENV=$(DEBUG_SHELLCONFIG=1 check_sixel_support 2>&1)
SIXEL_CAPABLE=$?
# if retcode is 0 then set SIXEL_CAPABLE to "true" else "false"
if [ "$SIXEL_CAPABLE" -eq 0 ]; then
  SIXEL_CAPABLE="true"
else
  SIXEL_CAPABLE="false"
fi
export SIXEL_ENV SIXEL_CAPABLE

${INTERACTIVE_SHELL:-false} && ${LOGIN_SHELL:-false} && fun_intro


[ -n "$DEBUG_SHELLCONFIG" ] && echo "Exiting $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")"
[ -n "$DEBUG_PATHCONFIG" ] && echo $PATH || :

# Added by LM Studio CLI (lms)
# export PATH="$PATH:/Users/pmarreck/.cache/lm-studio/bin"
# End of LM Studio CLI section


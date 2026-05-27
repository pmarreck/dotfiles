#!/bin/sh

# .profile must remain POSIX-compliant, use shellcheck to verify
# There is currently 1 exception to this rule: the use of ${BASH_SOURCE[0]} for debugging

in_bash() {
	[ -n "${BASH_VERSION+set}" ]
}

# Check if a variable, function, alias etc. is defined in the current context (which is why we need to define these here)
var_defined() {
	in_bash && [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	if in_bash; then
		declare -p "$1" >/dev/null 2>&1
	else
		# POSIX-compliant version is gross unfortunately:
		eval '[ "${'"$1"'+x}" ]'
	fi
}

func_defined() {
	in_bash && [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	# POSIX-compliant
	type "$1" 2>/dev/null | {
		IFS= read -r line || exit 1
		case $line in
			*function*) exit 0 ;;
			*)          exit 1 ;;
		esac
	}
}

alias_defined() {
	in_bash && [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	alias "$1" >/dev/null 2>&1
}

defined() {
	in_bash && [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	if [ $# -eq 0 ]; then
		printf '%s\n' "Usage: defined <function or alias or variable or builtin or executable-in-PATH name> [...function|alias] ..." \
			"Returns 0 if all the arguments are defined as a function or alias or variable or builtin or executable-in-PATH name." \
			"This function is defined in ${BASH_SOURCE[0]}"
		return 2
	fi
	for word; do
		if command -v -- "$word" >/dev/null 2>&1; then
			continue
		fi
		if var_defined "$word"; then
			continue
		fi
		return 1
	done
	return 0
}

func_defined truthy || . "$HOME/dotfiles/bin/src/truthy.sh"
func_defined append_dotfile_progress || . "$HOME/dotfiles/bin/src/append_dotfile_progress.sh"
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

# bin2hex is now an executable in $HOME/dotfiles/bin

# [ -n "$DEBUG_SHELLCONFIG" ] && echo "sourced nix-hash-retrievals.bash"

# config for Visual Studio Code
# if [ "$PLATFORM" = "mac" ]; then
#   code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode --args "$*" ;}
#   pipeable_code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode -f ;}
#   export PIPEABLE_EDITOR='pipeable_code'
# fi
# export EDITOR='code' # already set in .bashrc

# set default tab stops to 2 spaces
# Note that this may mess up ncurses code that might assume 8 spaces
# Only tweak tabs on an interactive TTY if `tabs` exists:
if ${INTERACTIVE_SHELL:-false} && command -v tabs >/dev/null 2>&1 && tty -s; then
	export DEFAULT_TABSIZE=2
	tabs -${DEFAULT_TABSIZE}
fi
# [ -n "$DEBUG_SHELLCONFIG" ] && echo "set tabs to 2 spaces"

# If you hate noise
# set bell-style visible

# ulimit. to see all configs, run `ulimit -a`
# ulimit -n 10000

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

# Pull in path configuration — but only if .bash_profile or .bashrc hasn't
# already done so upstream in this source chain. (Historically defensive against
# macOS mangling, but mangling happens at login time, before this re-source.)
# BASH_SOURCE check is bash-only; non-bash sh has empty BASH_SOURCE so the
# fallback fires normally. Catches both login chain (.bash_profile upstream)
# and standalone bash interactive (.bashrc upstream).
case " ${BASH_SOURCE[*]:-} " in
	*"/.bash_profile "*|*"/.bashrc "*) ;;  # parent already sourced .pathconfig
	*) . $HOME/.pathconfig ;;
esac
# [ -n "$DEBUG_SHELLCONFIG" ] && echo "sourced .pathconfig"

# codex function/wrapper
. $HOME/dotfiles/bin/src/codex.bash

# claude function/wrapper
. $HOME/dotfiles/bin/src/claude.bash

# capture function/wrapper
. $HOME/dotfiles/bin/src/capture.bash

# shadows function (only in bash)
in_bash && . "$HOME/dotfiles/bin/src/shadows.bash"

# universal stdout/stderr/returncode capturing
. $HOME/dotfiles/bin/src/capture.bash

# resolve function for expanding aliases and resolved paths recursively
. $HOME/dotfiles/bin/src/resolve.bash

SIXEL_ENV=$(DEBUG_SHELLCONFIG=1 check_sixel_support 2>&1)
SIXEL_CAPABLE=$?
# if retcode is 0 then set SIXEL_CAPABLE to "true" else "false"
if [ "$SIXEL_CAPABLE" -eq 0 ]; then
  SIXEL_CAPABLE="true"
else
  SIXEL_CAPABLE="false"
fi

# Also detect kitty graphics protocol (Ghostty, kitty, WezTerm). display_image
# prefers kitty when available, falls back to sixel — so IMAGE_CAPABLE is the
# real "can we render images" gate, broader than SIXEL_CAPABLE alone.
check_kitty_support >/dev/null 2>&1 && KITTY_CAPABLE="true" || KITTY_CAPABLE="false"
if [ "$SIXEL_CAPABLE" = "true" ] || [ "$KITTY_CAPABLE" = "true" ]; then
  IMAGE_CAPABLE="true"
else
  IMAGE_CAPABLE="false"
fi
export SIXEL_ENV SIXEL_CAPABLE KITTY_CAPABLE IMAGE_CAPABLE

if ${INTERACTIVE_SHELL:-false} && ${LOGIN_SHELL:-false} && [ -z "$SHELL_STARTUP_BENCHMARK" ]; then
	# Decoration via cache: display previously-cached pick instantly, then
	# bg-fork a regenerator so the NEXT shell has a fresh pick ready. The
	# regenerator uses expect to allocate a PTY (preserves ANSI), times out
	# after 5s (expect's `set timeout 5`), and logs to error.log on failure.
	# Cold start (no cache yet): fall through to a normal synchronous fun_intro
	# so the user sees something this time too, AND prime the cache for next.
	_fi_cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/fun_intro/cached"
	if [ -s "$_fi_cache" ]; then
		cat "$_fi_cache"
	else
		fun_intro
	fi
	# Double-fork so the regenerator survives this shell's exit.
	( ( fun_intro --regenerate-cache </dev/null >/dev/null 2>&1 & ) & ) </dev/null >/dev/null 2>&1
	unset _fi_cache
fi

[ -n "$DEBUG_SHELLCONFIG" ] && echo "Exiting $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")"
[ -n "$DEBUG_PATHCONFIG" ] && echo $PATH || :

# Added by LM Studio CLI (lms)
# export PATH="$PATH:/Users/pmarreck/.cache/lm-studio/bin"
# End of LM Studio CLI section

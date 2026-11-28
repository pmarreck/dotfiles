#!/bin/sh
# shellcheck disable=SC1091 # Sources resolve through $HOME at run time.

# .profile must remain POSIX: any login shell may read it, not just Bash (sh -l,
# dash, a display manager's /bin/sh). Every Bash-only line sits behind an
# `in_bash` check, which keeps it from running elsewhere; dash still parses an
# array expansion it never executes. bin/test/profile_posix_test runs this file
# under dash. Verify edits with `shellcheck -s sh .profile` as well.

# Keep long bc results, including binary output, on one line.
export BC_LINE_LENGTH=0

# Current-shell predicates must be sourced so they can inspect caller locals,
# functions, and aliases; an executable subprocess cannot observe that state.
. "$HOME/dotfiles/bin/src/defined_helpers.sh"

# Name this file for debug output: Bash knows its sourced path, sh does not.
_profile_name() {
	if in_bash; then
		# shellcheck disable=SC3028,SC3054 # Bash-only, reached only under Bash.
		printf '%s\n' "${BASH_SOURCE[0]}" | ${SED:-sed} "s|^$HOME|~|"
	else
		# shellcheck disable=SC2088 # A literal ~ for display.
		printf '%s\n' '~/.profile'
	fi
}

func_defined truthy || . "$HOME/dotfiles/bin/src/truthy.sh"
func_defined append_dotfile_progress || . "$HOME/dotfiles/bin/src/append_dotfile_progress.sh"
if truthy DEBUG_SHELLCONFIG; then
	echo "Entering $(_profile_name)"
elif ${INTERACTIVE_SHELL:-false} && ${LOGIN_SHELL:-false}; then
	append_dotfile_progress "prof"
fi
truthy DEBUG_PATHCONFIG && echo "$PATH"

${INTERACTIVE_SHELL:-false} && ${LOGIN_SHELL:-false} && echo "$DISTRO_PRETTY"

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
if ${INTERACTIVE_SHELL:-false} && command -v tabs >/dev/null 2>&1 && [ -t 0 ]; then
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
# .pathconfig and the function wrappers below are Bash. The BASH_SOURCE call
# stack shows whether .bash_profile or .bashrc already sourced .pathconfig
# upstream in this chain (the login chain, or a standalone interactive Bash).
if in_bash; then
	# shellcheck disable=SC3028,SC3054 # Bash-only, reached only under Bash.
	case " ${BASH_SOURCE[*]:-} " in
		*"/.bash_profile "*|*"/.bashrc "*) ;;  # parent already sourced .pathconfig
		*) . "$HOME/.pathconfig" ;;
	esac

	# Function wrappers for agent CLIs
	. "$HOME/dotfiles/bin/src/codex.bash"
	. "$HOME/dotfiles/bin/src/claude.bash"
	. "$HOME/dotfiles/bin/src/agy.bash"     # Antigravity CLI
	# Universal stdout/stderr/return-code capture
	. "$HOME/dotfiles/bin/src/capture.bash"
	# shadows: report PATH entries that shadow one another
	. "$HOME/dotfiles/bin/src/shadows.bash"
	# resolve: expand aliases and resolved paths recursively
	. "$HOME/dotfiles/bin/src/resolve.bash"
fi

# The startup engine (.pathconfig) computed the terminal graphics facts:
# SIXEL_ENV (the Sixel verdict), SIXEL_CAPABLE, KITTY_CAPABLE, and
# IMAGE_CAPABLE, the "can this terminal show images" gate. Export them for
# the intro and other tools.
export SIXEL_ENV SIXEL_CAPABLE KITTY_CAPABLE IMAGE_CAPABLE

# Terminal tabs can start interactive Bash without making it a login shell.
# The intro renders its pick live in one LuaJIT process (lib/fun_intro), on
# the LuaJIT .pathconfig resolved; images join the pool only when
# IMAGE_CAPABLE says this terminal can show them.
if ${INTERACTIVE_SHELL:-false} && [ -t 0 ] && [ -t 1 ] && [ -z "${SHELL_STARTUP_BENCHMARK:-}" ]; then
	"${_SHELL_STARTUP_LUAJIT:-luajit}" "$HOME/dotfiles/bin/fun_intro"
fi

[ -n "${DEBUG_SHELLCONFIG:-}" ] && echo "Exiting $(_profile_name)"
unset -f _profile_name
[ -n "${DEBUG_PATHCONFIG:-}" ] && echo "$PATH" || :

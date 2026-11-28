#!/usr/bin/env bash
# shellcheck disable=SC2001

# Login shells read this file: every macOS terminal tab, and on Linux usually
# only a console or SSH login (a terminal tab there is a non-login shell that
# reads only .bashrc). So it sources .bashrc, which holds everything every
# interactive shell needs, and keeps here only what belongs to a login.
# export DEBUG_SHELLCONFIG=true
# export DEBUG_PATHCONFIG=true

# .bashrc checks the Bash version; it is sourced below on every path.

# Record what kind of shell this is; .bashrc recomputes the same two flags.
shopt -q login_shell && LOGIN_SHELL=true || LOGIN_SHELL=false
[[ $- == *i* ]] && INTERACTIVE_SHELL=true || INTERACTIVE_SHELL=false

. "$HOME/dotfiles/bin/src/append_dotfile_progress.sh"

# Debug mode lists each startup file; otherwise login shells show progress.
if [ -n "${DEBUG_SHELLCONFIG+set}" ]; then
	echo "Entering ${BASH_SOURCE[0]/#"$HOME"/"~"}"
elif $INTERACTIVE_SHELL && $LOGIN_SHELL; then
	append_dotfile_progress "bp"
fi
[ "${DEBUG_PATHCONFIG+set}" = "set" ] && echo "$PATH"

# subtle shell characteristics indication, but only if interactive
if $INTERACTIVE_SHELL; then
	append_dotfile_progress "interactive"
	if $LOGIN_SHELL; then
		append_dotfile_progress "login"
	else
		append_dotfile_progress "non-login"
	fi
fi

# Pull in path configuration
# shellcheck disable=SC1090
. "$HOME/.pathconfig"
# .bashrc defines everything every interactive shell shares (the tmux session
# helper, AWK, ...): a Linux terminal tab is not a login shell and never reads
# this file, while every macOS tab is.

# Warp terminal seems to have nonstandard behavior and non-gnu sed breaks things
# so we are using this workaround:
# Set SED env var to first gnu sed found on PATH; otherwise warn
# Use [[ "$($candidate_sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]] to detect
# Find the first GNU sed in PATH
# The startup engine (.pathconfig) made this choice from cached --version
# answers; the loop runs only when it did not.
unset SED
if [ -n "${SHELL_STARTUP_LOGIN_SED+set}" ]; then
	[ -n "$SHELL_STARTUP_LOGIN_SED" ] && export SED=$SHELL_STARTUP_LOGIN_SED
else
	for candidate_sed in $(type -a -p gsed) $(type -a -p sed); do
		if [[ "$($candidate_sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]]; then
			export SED=$candidate_sed
			break
		fi
	done
fi
# Warn if no GNU sed found
if [ -z "${SED+x}" ]; then
	echo "Warning from .bash_profile: No GNU sed found in PATH. This may result in problems. Using system's default sed." >&2
	SED=$(command -v sed); export SED
fi

# enable timing debugging
# PS4='+ \D{%s} \011 '
# PS4='+ $(/Users/pmarreck/.nix-profile/bin/date "+%s.%N")\011 '
# exec 3>&2 2>/tmp/bashstart.$$.log
# set -x

[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc"

# disable timing debugging
# set +x
# exec 2>&3 3>&-

# Added by OrbStack: command-line tools and integration
# Comment this line if you don't want it to be added again.
# source ~/.orbstack/shell/init.bash 2>/dev/null || :

# enable tests if any script modification times are different
# Skip for LLM assistants to prevent hangs
if [[ "${SKIP_COMPLEX_SHELL_SETUP:-false}" != "true" ]] && [[ "${ENABLE_DOTFILE_TESTS:-false}" == "true" ]]; then
	. "${HOME}/dotfiles/run_tests_on_change.sh"
fi

# Warn (cheaply, warn-only) if root-owned system mutations declared in the
# nix-darwin flake (~/.config/nix) have drifted or been wiped by a macOS
# update. Fix is always: sudo darwin-rebuild switch --flake ~/.config/nix
# The check is a no-op elsewhere, so skip forking it off macOS.
[ "$OS" = macos ] && command -v check-system-mutations >/dev/null 2>&1 && check-system-mutations || :

truthy DEBUG_SHELLCONFIG && echo "Exiting $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")"
truthy DEBUG_PATHCONFIG && echo "$PATH" || :

# oMLX: CLI shim path begin
# (moved to declared_additions in lib/shell_startup/path_plan.lua; markers kept so the installer sees its block)
# case ":$PATH:" in
#   *":$HOME/.omlx/bin:"*) ;;
#   *) export PATH="$HOME/.omlx/bin:$PATH" ;;
# esac
# oMLX: CLI shim path end

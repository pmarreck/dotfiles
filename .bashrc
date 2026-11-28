#!/usr/bin/env bash

# shellcheck disable=SC2001

# So for debug switches, we will check whether they are even set using [[ -v VARNAME ]]
# because we do not want to pollute the env with the unnecessary presence of
# debug switches that are just set to false.
# But note that that only works in Bash 4+!
# For all other configs, just set to true/false as appropriate (but never blank!)
# export _TRACE_SOURCING=true
# export DEBUG_SHELLCONFIG=true
# export DEBUG_PATHCONFIG=true

# require at least Bash 4.2
if [[ $BASH_VERSION =~ ^([0-9]+)\.([0-9]+) ]]; then
	if (( BASH_REMATCH[1] > 4 || ( BASH_REMATCH[1] == 4 && BASH_REMATCH[2] >= 2 ) )); then
		: # echo "Bash version is greater than or equal to 4.2"
	else
		echo "Warning: Bash version less than 4.2 detected. Expect incompatible behavior." >&2
	fi
else
	echo "Warning: Couldn't parse Bash version: $BASH_VERSION"
fi

# Build PATH once, before anything below looks up a command. A login shell's
# .bash_profile has already sourced .pathconfig; the BASH_SOURCE call stack (local to
# this source chain, never an exported flag) shows that. Every other entry, such as a
# terminal tab, tmux pane, or SSH session, starts here and needs PATH built now.
case " ${BASH_SOURCE[*]} " in
	*"/.bash_profile "*) ;;
	*) . "$HOME/.pathconfig" ;;
esac

# Startup repeats these lookups dozens of times. Executing the helper scripts costs a
# Bash startup and two PATH walks per call, so define them in this shell instead
# (bin/test/shell_startup_exec_budget_test).
. "$HOME/dotfiles/bin/needs"
. "$HOME/dotfiles/bin/array_contains_element"

# Turn off command hashing
set +h

export NULL=${NULL:-/dev/null}

# I use "truthy" everywhere but it has to be defined in the current context
# since it reads variable values, which wouldn't be seen by it if it was run
# as an executable unless that variable was exported, which is not what we want
. "$HOME/dotfiles/bin/src/truthy.sh"
# Truthy contains its own debug function that does not depend on truthy,
# to prevent the circular dependency.
debug() {
	if [ $# = 0 ]; then
		truthy DEBUG
	else
		if truthy DEBUG; then
			echo -e "\033[33mDEBUG: $*\033[0m" >&2
		fi
	fi
}

# For ripgrepping instead of grepping, with fallback.
# Exported as a STRING (bash arrays cannot be exported to child processes).
# Consumers rehydrate it into an argv array with:
#   read -ra GREP_QUIET_ARRAY <<< "${GREP_QUIET:-grep -q}"
# which keeps word-splitting/globbing safe while still crossing the exec boundary.
if needs rg "please install ripgrep"; then
	export GREP_QUIET="rg -q --fixed-strings"
else
	export GREP_QUIET="grep -q"
fi
read -ra GREP_QUIET_ARRAY <<< "$GREP_QUIET"

# determine shell characteristics
# is this an interactive shell? login shell?
# set LOGIN_SHELL and INTERACTIVE_SHELL here
shopt -q login_shell && LOGIN_SHELL=true || LOGIN_SHELL=false
[[ $- == *i* ]] && INTERACTIVE_SHELL=true || INTERACTIVE_SHELL=false

# Skip complex setup in a shell started by an LLM coding assistant (Claude
# Code, Codex, ...). Only the parent process's name decides: $0 and $_ hold
# paths, and a home or temporary directory can contain "claude" by accident.
# The startup engine (.pathconfig) already named the parent process; ps is
# only the fallback for a shell that reached this file without it.
_llm_parent_command=''
if [[ -n "${SHELL_STARTUP_PARENT_COMMAND+set}" ]]; then
	_llm_parent_command=$SHELL_STARTUP_PARENT_COMMAND
elif [[ -n "${PPID:-}" ]]; then
	_llm_parent_command=$(ps -p "${PPID}" -o comm= 2>/dev/null)
fi
if [[ "$_llm_parent_command" =~ (claude|codex|llm|assistant) ]]; then
	export SKIP_COMPLEX_SHELL_SETUP=true
fi
unset _llm_parent_command

# most things should be sourced via source_relative... except source_relative itself
# if the function is not already defined, define it. use posix syntax for portability
# shellcheck disable=SC1090

# define silently function here because it needs to know vars in the current namespace
. "$HOME/dotfiles/bin/src/silently.sh"

# have to define show here for the same reason we have to define truthy...
. "$HOME/dotfiles/bin/src/show.bash"

# have to source "functions" function for it to be able to see in-context functions
. "$HOME/dotfiles/bin/src/functions.bash"

# have to source "edit" function for it to be able to see the functions via "functions"... lol sigh
. "$HOME/dotfiles/bin/src/edit.bash"

# `code <partial>` jumps to a ~/Code project by fuzzy name (needs cd → must be sourced)
. "$HOME/dotfiles/bin/src/code.bash"

# tmux new-or-rejoin helper. Here rather than in .bash_profile, so non-login
# shells (Linux terminal tabs, tmux panes) get it as every macOS tab does.
. "$HOME/dotfiles/bin/src/session.bash"

# Set SED env var - with Nix, sed is already GNU sed
if [ -z ${SED+x} ]; then
	if [[ "$(sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]]; then
		export SED="sed"
	else
		echo "Warning from .bashrc: sed is not GNU sed. Some scripts may fail." >&2
		export SED="sed"
	fi
fi
# echo "SED in .bashrc:56 is: $SED"
# Awk-ward! (see note below about "using the right awk"...)
[ -z "${AWK+x}" ] && \
	export AWK=$(command -v frawk || command -v gawk || command -v awk)

# Debug mode lists each startup file; otherwise login shells show progress.
if [ -n "${DEBUG_SHELLCONFIG+set}" ]; then
	echo "Entering ${BASH_SOURCE[0]/#"$HOME"/"~"}"
elif $INTERACTIVE_SHELL && $LOGIN_SHELL; then
	append_dotfile_progress "rc"
fi
[ "${DEBUG_PATHCONFIG+set}" = "set" ] && echo "$PATH"

# direnv output cannot be muted due to bug in version 2.36.0
# See: https://github.com/direnv/direnv/issues/1418

# blesh (ble.sh) config
# needs the system stty softlinked from ~/bin (or ~/dotfiles/bin) to temporarily be ahead of PATH for ble.sh to work
# _OLD_PATH="$PATH"
# PATH="$HOME/bin:$PATH"
# needs blesh-share "please install blesh" && source `blesh-share`/ble.sh
# $INTERACTIVE_SHELL && source `blesh-share`/ble.sh --noattach
# PATH="$_OLD_PATH"
# unset _OLD_PATH

# User configuration
# export MANPATH="/usr/local/man:$MANPATH"

# The locale (LANG, LANGUAGE, LC_CTYPE) is set in .envconfig.

# Preferred editors. EDITOR is a terminal editor, which always blocks. Most
# tools (crontab -e, sudoedit, less's v, Bash's Ctrl-X Ctrl-E) prefer VISUAL
# and read the file back as soon as the editor command exits, so VISUAL is
# `choose_editor --wait`: Zed where its window can reach you, blocking until
# the file is closed, otherwise micro. choose_editor also tells the Zed editor
# from the ZFS event daemon, which is named zed too. Over SSH VISUAL stays
# unset, which tells tools there is no local GUI.
unset VISUAL EDITOR
needs micro "please install the micro editor; defaulting to nano" && export EDITOR='micro' || export EDITOR='nano'
if [[ -z ${SSH_CONNECTION:-} ]]; then
	export VISUAL='choose_editor --wait'
fi

# Compilation flags used by macOS native-extension builds.
if [ "$OS" = macos ]; then
	ARCHFLAGS="-arch $(uname -m)"
	export ARCHFLAGS
fi

# ssh
export SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# Guix integration
[[ -s "$HOME/.guix-profile/etc/profile" ]] && source $HOME/.guix-profile/etc/profile

# Distribution information. Canonical OS/ARCH/PLATFORM/PF/WSL are exported by
# .pathconfig before this point and must retain their execution-platform meaning.
case $OS in
	macos)
		# .pathconfig's engine run normally exported all three already, read
		# from SystemVersion.plist and the name table in
		# bin/mac_os_version_number_to_name; these commands are the fallback.
		if [ -z "${SHELL_STARTUP_MACOS_FACTS-}" ]; then
			export DISTRO="macOS"
			if command -v mac_os_version_number_to_name >/dev/null 2>&1 && command -v sw_vers >/dev/null 2>&1; then
				MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null)"
				if [ -n "$MACOS_VERSION" ]; then
					export DISTRO_PRETTY="$DISTRO $(mac_os_version_number_to_name "$MACOS_VERSION")"
				else
					export DISTRO_PRETTY="$DISTRO"
				fi
			else
				export DISTRO_PRETTY="$DISTRO"
			fi
			unset MACOS_VERSION
			export DISTRO_VERSION="$(distro_version)"
		fi
		# Initialize RAM disk for /private/tmp if interactive login shell
		# NOTE: This is now handled by a LaunchAgent (com.pmarreck.ramdisk.plist)
		# which runs ~/dotfiles/bin/ramdisk-daemon on login. Use 'ramdisk-status' to check status.
		# Disabled the old method to prevent conflicts:
		# if $INTERACTIVE_SHELL && $LOGIN_SHELL; then
		#   "$HOME/dotfiles/bin/src/macos_ramdisk_tmp.sh"
		# fi
		;;
	linux)
		# .pathconfig's engine run already exported DISTRO, DISTRO_PRETTY, and
		# DISTRO_VERSION, parsed from /etc/os-release exactly as bin/distro,
		# bin/distro_pretty, and bin/distro_version read it.
		;;
	mswin)
		export DISTRO="Windows"
		export DISTRO_PRETTY="$(distro_pretty)"
		export DISTRO_VERSION="$(distro_version)"
		;;
esac

# echo "AWK in .bashrc:258 is: $AWK"
# using the right awk is a PITA on macOS vs. Linux so let's ensure GNU Awk everywhere
# Only an awk named plain "awk" on macOS can be BSD awk, so only that one is
# asked for its version, and without piping it through another program.
if [ "$OS" = macos ] && [ "${AWK##*/}" = awk ]; then
	is_gnu_awk=false
	[[ "$($AWK --version 2>/dev/null)" == *"GNU Awk"* ]] && is_gnu_awk=true
	if [ "$is_gnu_awk" = false ]; then
		echo "WARNING: The awk on PATH is not GNU Awk on macOS, which may cause problems" >&2
	fi
fi

# # asdf config
# [[ -s "$HOME/.asdf/asdf.sh" ]] && source "$HOME/.asdf/asdf.sh"
# [[ -s "$HOME/.asdf/completions/asdf.bash" ]] && source "$HOME/.asdf/completions/asdf.bash"
# export ASDF_INSTALL_PATH=$ASDF_DIR

# # mix config to fix an asdf issue that cropped up
# export MIX_HOME="$HOME/.mix"
# export MIX_ARCHIVES="$MIX_HOME/archives"

# partial history search
if $INTERACTIVE_SHELL
then
	bind '"\e[A": history-search-backward' # up-arrow
	bind '"\e[B": history-search-forward'  # down-arrow
fi

# who am I? (should work even when sourced from elsewhere, but only in Bash)
me() {
	[ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	basename -- "${BASH_SOURCE[0]}"
}

needs eza "cargo install eza, or your package manager"
needs tokei "cargo install --git https://github.com/XAMPPRocky/tokei.git tokei, or your package manager"
needs micro "please install the micro terminal editor"

# for git paging:
needs delta "cargo install git-delta"

# ble.sh
# Uncomment when the following fix makes it to mainstream branches:
# https://github.com/jeffkreeftmeijer/system/commit/e54f0755f3b5c9f8888ac06bd1bb92d9ff52e709
# needs blesh-share "please install ble.sh > v0.4"
# source `blesh-share`/ble.sh

# environment vars config
. $HOME/.envconfig

# source posix profile
[[ -s "$HOME/.profile" ]] && . $HOME/.profile # Load the default .profile

# Load hooks (skip during rehash to avoid issues)
# Skip all hook loading for LLM assistants to prevent hangs
# Generic detection of VS Code Agent/Background context
# If we are in VS Code (TERM_PROGRAM=vscode) but lack the shell integration (__vsc_prompt_cmd),
# we assume we are in a background agent (run_command) and should skip complex hooks.
# This supports forks of VS Code/Antigravity without relying on specific env vars.
IS_VSCODE_AGENT=false
if [[ "${TERM_PROGRAM}" == "vscode" ]]; then
	if ! declare -F __vsc_prompt_cmd >/dev/null && [[ "${PROMPT_COMMAND:-}" != *"__vsc_prompt_cmd"* ]]; then
		IS_VSCODE_AGENT=true
	fi
fi


if $INTERACTIVE_SHELL && [[ "$IS_VSCODE_AGENT" == "false" ]]; then
	if [[ "${SKIP_COMPLEX_SHELL_SETUP:-false}" == "true" ]]; then
		# Minimal setup for LLM assistants - just basic prompt
		PS1='\u@\h:\w\$ '
		unset PROMPT_COMMAND PS0 precmd_functions preexec_functions
		trap - DEBUG
	elif [[ "${REHASHING:-false}" != "true" ]] && [[ "${ENABLE_COMPLEX_HOOKS:-false}" == "true" ]]; then
		if [[ -f "$HOME/bin/apply-hooks" ]]; then
			source "$HOME/bin/apply-hooks" || echo "Problem when sourcing $HOME/bin/apply-hooks"
		else
			echo "apply-hooks not found at $HOME/bin/apply-hooks" >&2
		fi
	elif [[ "${REHASHING:-false}" != "true" ]]; then
		# Use simplified hooks that won't hang
		if [[ -f "$HOME/dotfiles/bin/apply-hooks" ]]; then
			source "$HOME/dotfiles/bin/apply-hooks" || echo "Problem when sourcing apply-hooks"
		else
			# Fallback: basic prompt if nothing else works
			PS1='\u@\h:\w\$ '
		fi
	fi
else
	# Non-interactive or Agent environment: Encapsulate and sanitize!
	# We typically inherit env vars from the parent shell which might have
	# complex hooks (PS0, PROMPT_COMMAND). We must unset them to prevent
	# "function not found" errors and output corruption.
	unset PROMPT_COMMAND PS0 precmd_functions preexec_functions
	trap - DEBUG
fi

# Shell refresh must be a function in this process; the executable form cannot
# mutate its parent shell.
# shellcheck disable=SC1091
. "$HOME/dotfiles/bin/rehash"

# aliases- source these on every interactive shell because they do not inherit
$INTERACTIVE_SHELL && . "$HOME/.aliases"

# Keep globbing/shell expansion off by default due to possible unexpected behavior
set -f

# Turn history expansion off because I like my exclamations unadulterated
# (and never use history expansion anyway)
# TODO: function to turn on history expansion temporarily, like what I do
# with the expand function to handle globbing
set +H

# Tab completion for show/what/d commands
. "$HOME/dotfiles/completions/show_completion.bash"

# Tab completion for grok. The PATH half of what the grok installer appended
# lives in .pathconfig with the other AI agent CLIs; only the completion
# sourcing belongs here, alongside the rest of the completions.
[[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && . "$HOME/.grok/completions/bash/grok.bash"

# Hook and unhook functions for wrapping commands with logging
. "$HOME/dotfiles/bin/src/hook.sh"
. "$HOME/dotfiles/bin/src/unhook.sh"

# mkdir-custom function for enhanced mkdir with -c/--cd option
. "$HOME/dotfiles/bin/src/mkdir-custom"

# pman for pretty man pages
. "$HOME/dotfiles/bin/src/pman_nice_man_pages.sh"

# activate ble.sh/blesh
# [[ ! ${BLE_VERSION-} ]] || ble-attach

# consistent deterministic randomization in subshells
export DRANDOM_CONTEXT=$$

# Append Warp and McFly history to shell history
# if command -v warp-history &> /dev/null; then
# 	warp-history --shell bash
# fi

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

# determine shell characteristics
# is this an interactive shell? login shell?
# set LOGIN_SHELL and INTERACTIVE_SHELL here
shopt -q login_shell && LOGIN_SHELL=true || LOGIN_SHELL=false
[[ $- == *i* ]] && INTERACTIVE_SHELL=true || INTERACTIVE_SHELL=false

# Detect if being run by Claude CLI or other LLM assistants and skip complex setup
if [[ "${PPID:-}" ]] && ps -p "${PPID}" -o comm= 2>/dev/null | grep -q "claude\|llm\|assistant"; then
		export SKIP_COMPLEX_SHELL_SETUP=true
elif [[ "$0" == *"claude"* ]] || [[ "${_:-}" == *"claude"* ]]; then
		export SKIP_COMPLEX_SHELL_SETUP=true
fi

# most things should be sourced via source_relative... except source_relative itself
# if the function is not already defined, define it. use posix syntax for portability
# shellcheck disable=SC1090

# define silently function here because it needs to know vars in the current namespace
. "$HOME/dotfiles/bin/src/silently.sh"

# have to define show here for the same reason we have to define truthy...
. "$HOME/dotfiles/bin/src/show.sh"

# have to source "functions" function for it to be able to see in-context functions
. "$HOME/dotfiles/bin/src/functions.bash"

# have to source "edit" function for it to be able to see the functions via "functions"... lol sigh
. "$HOME/dotfiles/bin/src/edit.bash"

# Pull in path configuration
. $HOME/.pathconfig

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

[ "${DEBUG_SHELLCONFIG+set}" = "set" ] && echo "Entering $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")" || $INTERACTIVE_SHELL && $LOGIN_SHELL && append_dotfile_progress "rc"
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

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor with logic for local and remote sessions
unset VISUAL EDITOR
if [[ -n $SSH_CONNECTION ]]; then
	needs micro "please install the micro editor; defaulting to nano" && export EDITOR='micro' || export EDITOR='nano'
	unset VISUAL # note: this indicates to other tooling later on that we are not in a GUI context
else
	needs micro "please install the micro editor; defaulting to nano for EDITOR" && export EDITOR='micro' || export EDITOR='nano'
	needs code "please install the VSCode editor and commandline access for it" && export VISUAL='code' || export VISUAL="$EDITOR"
	needs windsurf "please install the Codeium Windsurf editor and commandline access for it" && export VISUAL='windsurf -g' || export VISUAL="${VISUAL:-$EDITOR}"
fi

# Compilation flags
# export ARCHFLAGS="-arch arm64"
ARCHFLAGS="-arch $(uname -a | rev | cut -d ' ' -f 2 | rev)"
export ARCHFLAGS
# note: "aarch64" may need to be mutated to "arm64" in some cases

# ssh
export SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# Guix integration
[[ -s "$HOME/.guix-profile/etc/profile" ]] && source $HOME/.guix-profile/etc/profile

# platform info
export PLATFORM
case $OSTYPE in
	darwin*)
		export PLATFORM="osx"
		export DISTRO="macOS"
		export DISTRO_PRETTY="$DISTRO $(mac_os_version_number_to_name)"
		export DISTRO_VERSION="$(distro_version)"
		# Initialize RAM disk for /private/tmp if interactive login shell
		# NOTE: This is now handled by a LaunchAgent (com.pmarreck.ramdisk.plist)
		# which runs ~/dotfiles/bin/ramdisk-daemon on login. Use 'ramdisk-status' to check status.
		# Disabled the old method to prevent conflicts:
		# if $INTERACTIVE_SHELL && $LOGIN_SHELL; then
		#   "$HOME/dotfiles/bin/src/macos_ramdisk_tmp.sh"
		# fi
		;;
	linux*)
		export PLATFORM="linux"
		export DISTRO="$(distro)"
		export DISTRO_PRETTY="$(distro_pretty)"
		export DISTRO_VERSION="$(distro_version)"
		;;
	msys*|cygwin*|mingw*)
		export PLATFORM="windows"
		export DISTRO="Windows"
		export DISTRO_PRETTY="$(distro_pretty)"
		export DISTRO_VERSION="$(distro_version)"
		;;
	*)
		# this downcase requires bash 4+; you can pipe to tr '[:upper:]' '[:lower:]' instead
		export PLATFORM="$OSTYPE"
		;;
esac

if [ "$AWK" = "" ]; then
	export AWK=$(command -v frawk || command -v gawk || command -v awk)
fi
# echo "AWK in .bashrc:258 is: $AWK"
# using the right awk is a PITA on macOS vs. Linux so let's ensure GNU Awk everywhere
is_gnu_awk=$($AWK --version | grep -q -m 1 'GNU Awk' && echo true || echo false)
[ "${PLATFORM}$(basename $AWK)" == "osxawk" ] && \
	$is_gnu_awk && \
	echo "WARNING: The awk on PATH is not GNU Awk on macOS, which may cause problems" >&2

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
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	basename -- "${BASH_SOURCE[0]}"
}

needs eza "cargo install eza, or your package manager"
needs tokei "cargo install --git https://github.com/XAMPPRocky/tokei.git tokei, or your package manager"
needs micro "please install the micro terminal editor"
needs code "please install VSCode"

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
if [[ "${SKIP_COMPLEX_SHELL_SETUP:-false}" == "true" ]]; then
	# Minimal setup for LLM assistants - just basic prompt
	PS1='\u@\h:\w\$ '
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

# Hook and unhook functions for wrapping commands with logging
. "$HOME/dotfiles/bin/src/hook.sh"
. "$HOME/dotfiles/bin/src/unhook.sh"

# activate ble.sh/blesh
# [[ ! ${BLE_VERSION-} ]] || ble-attach

# Added by LM Studio CLI (lms)
# export PATH="$PATH:/Users/pmarreck/.cache/lm-studio/bin"
# End of LM Studio CLI section

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
prepend_path "$PNPM_HOME"
# pnpm end

#!/usr/bin/env bash
# shellcheck disable=SC2001

# This file should only source .bashrc,
# and contain commands only applicable to interactive shells.
# In my current config, this is usually the file that loads first (FYI).
# export DEBUG_SHELLCONFIG=true
# export DEBUG_PATHCONFIG=true

# Require at least Bash 4.2
if [[ $BASH_VERSION =~ ^([0-9]+)\.([0-9]+) ]]; then
  if (( BASH_REMATCH[1] > 4 || ( BASH_REMATCH[1] == 4 && BASH_REMATCH[2] >= 2 ) )); then
    : # echo "Bash version is greater than or equal to 4.2"
  else
    echo "Warning: Bash version less than 4.2 detected. Expect incompatible behavior." >&2
  fi
else
  echo "Warning: Couldn't parse Bash version: $BASH_VERSION" >&2
fi

# since .bash_profile is usually only included for non-login shells
# (note: OS X Terminal ALWAYS runs as a login shell but still ALWAYS includes this file, but it's nonstandard)
# set LOGIN_SHELL and INTERACTIVE_SHELL here but only if it wasn't already set
shopt -q login_shell && LOGIN_SHELL=true || LOGIN_SHELL=false
[[ $- == *i* ]] && INTERACTIVE_SHELL=true || INTERACTIVE_SHELL=false

. "$HOME/dotfiles/bin/src/append_dotfile_progress.sh"

[ "${DEBUG_SHELLCONFIG+set}" = "set" ] && echo "Entering $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")" || $INTERACTIVE_SHELL && $LOGIN_SHELL && append_dotfile_progress "bp"
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

# most things should be sourced via source_relative... except source_relative itself
# if the function is not already defined, define it. use posix syntax for portability
# shellcheck disable=SC1090

# Pull in path configuration
. $HOME/.pathconfig
# tmux helpers
. "$HOME/dotfiles/bin/src/session.bash"

# Warp terminal seems to have nonstandard behavior and non-gnu sed breaks things
# so we are using this workaround:
# Set SED env var to first gnu sed found on PATH; otherwise warn
# Set SED env var - with Nix, sed is already GNU sed
if [ -z ${SED+x} ]; then
  if [[ "$(sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]]; then
    export SED="sed"
  else
    echo "Warning from .bash_profile: sed is not GNU sed. Some scripts may fail." >&2
    export SED="sed"
  fi
fi

# echo "SED in .bash_profile:56 is: $SED"
# Awk-ward! (see note below about "using the right awk"...)
[ -z "${AWK+x}" ] && \
  export AWK=$(command -v frawk || command -v gawk || command -v awk)

# Warp terminal seems to have nonstandard behavior and non-gnu sed breaks things
# so we are using this workaround:
# Set SED env var to first gnu sed found on PATH; otherwise warn
# Use [[ "$($candidate_sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]] to detect
# Find the first GNU sed in PATH
unset SED
for candidate_sed in $(type -a -p gsed) $(type -a -p sed); do
  if [[ "$($candidate_sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]]; then
    export SED=$candidate_sed
    break
  fi
done
# Warn if no GNU sed found
if [ -z ${SED+x} ]; then
  echo "Warning from .bash_profile: No GNU sed found in PATH. This may result in problems. Using system's default sed." >&2
  export SED=`which sed`
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

truthy DEBUG_SHELLCONFIG && echo "Exiting $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")"
truthy DEBUG_PATHCONFIG && echo "$PATH" || :


# Added by LM Studio CLI (lms)
# export PATH="$PATH:/Users/pmarreck/.cache/lm-studio/bin"
# End of LM Studio CLI section

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

append_dotfile_progress() {
    # Expand the abbreviated names
    local expanded_name
    case "$1" in
        "bp") expanded_name=".bash_profile" ;;
        "rc") expanded_name=".bashrc" ;;
        "env") expanded_name=".envconfig" ;;
        "P") expanded_name=".pathconfig" ;;
        "prof") expanded_name=".profile" ;;
        *) expanded_name="$1" ;;
    esac
    
    # Prevent duplicate entries
    if [[ ! $LAST_DOTFILE_RUN =~ ${expanded_name}-loaded\; ]]; then
        export LAST_DOTFILE_RUN="${LAST_DOTFILE_RUN:-}${expanded_name}-loaded;"
    fi
}

# since .bash_profile is usually only included for non-login shells
# (note: OS X Terminal ALWAYS runs as a login shell but still ALWAYS includes this file, but it's nonstandard)
# set LOGIN_SHELL and INTERACTIVE_SHELL here but only if it wasn't already set
shopt -q login_shell && LOGIN_SHELL=true || LOGIN_SHELL=false
[[ $- == *i* ]] && INTERACTIVE_SHELL=true || INTERACTIVE_SHELL=false

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
[ "`type -t source_relative_once`" = "function" ] || . "$HOME/dotfiles/bin/functions/source_relative.bash"

# Pull in path configuration
source_relative_once .pathconfig

# prefer gnu sed installed via nix, otherwise warn
SED=$(command -v gsed 2>/dev/null || command -v sed)
[[ "$($SED --version | head -1)" =~ .*GNU.* ]] || echo "WARNING from .bash_profile: The sed on PATH is not GNU sed, which may cause problems" >&2 && SED="/run/current-system/sw/bin/sed"
export SED

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
source_relative_once "${HOME}/dotfiles/run_tests_on_change.sh"

[ "${DEBUG_SHELLCONFIG+set}" = "set" ] && echo "Exiting $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")"
[ "${DEBUG_PATHCONFIG+set}" = "set" ] && echo "$PATH" || :

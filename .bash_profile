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

[ "${DEBUG_SHELLCONFIG+set}" = "set" ] && echo "Entering $(echo "${BASH_SOURCE[0]}" | sed "s|^$HOME|~|")" || printf "#"
[ "${DEBUG_PATHCONFIG+set}" = "set" ] && echo "$PATH"
# since .bash_profile is usually only included for non-login shells
# (note: OS X Terminal ALWAYS runs as a login shell but still ALWAYS includes this file, but it's nonstandard)
export LOGIN_SHELL=false

# enable timing debugging
# PS4='+ \D{%s} \011 '
# PS4='+ $(/Users/pmarreck/.nix-profile/bin/date "+%s.%N")\011 '
# exec 3>&2 2>/tmp/bashstart.$$.log
# set -x

# enable tests if any script modification times are different
source "${HOME}/dotfiles/run_tests_on_change.sh"

[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc"

# disable timing debugging
# set +x
# exec 2>&3 3>&-

[ "${DEBUG_SHELLCONFIG+set}" = "set" ] && echo "Exiting $(echo "${BASH_SOURCE[0]}" | sed "s|^$HOME|~|")"
[ "${DEBUG_PATHCONFIG+set}" = "set" ] && echo "$PATH" || :

# Added by OrbStack: command-line tools and integration
# Comment this line if you don't want it to be added again.
source ~/.orbstack/shell/init.bash 2>/dev/null || :

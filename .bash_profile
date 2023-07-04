# This file should only source .bashrc,
# and contain commands only applicable to interactive shells
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

[[ -v DEBUG_SHELLCONFIG ]] && echo "Entering $(echo "${BASH_SOURCE[0]}" | sed "s|^$HOME|~|")" || printf "#"
[[ -v DEBUG_PATHCONFIG ]] && echo $PATH
# since .bash_profile is usually only included for non-login shells
# (note: OS X Terminal ALWAYS runs as a login shell but still ALWAYS includes this file, but it's nonstandard)
export LOGIN_SHELL=false

[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc"

[[ -v DEBUG_SHELLCONFIG ]] && echo "Exiting $(echo "${BASH_SOURCE[0]}" | sed "s|^$HOME|~|")"
[[ -v DEBUG_PATHCONFIG ]] && echo $PATH

# This file should only source .bashrc,
# and contain commands only applicable to interactive shells

false && [[ $- == *i* ]] && echo "Running .bash_profile" || echo -n "#"

# since .bash_profile is usually only included for non-login shells
# (note: OS X Terminal ALWAYS runs as a login shell but still ALWAYS includes this file, but it's nonstandard)
export LOGIN_SHELL=false

[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc"

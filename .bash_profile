[[ $- == *i* ]] && echo "Running .bash_profile"

# This file should only source .bashrc,
# and contain commands only applicable to interactive shells

[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc" # Load the default .profile

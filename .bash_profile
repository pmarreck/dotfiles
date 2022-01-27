DEBUG_SHELLCONFIG=false

# mute direnv constantly telling me what it's loading
export DIRENV_LOG_FORMAT=

$DEBUG_SHELLCONFIG && [[ $- == *i* ]] && echo "Running .bash_profile" || echo -n "#"

# This file should only source .bashrc,
# and contain commands only applicable to interactive shells

[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc" # Load the default .profile

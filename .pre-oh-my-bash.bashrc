[[ $- == *i* ]] && echo "Running .pre-oh-my-bash.bashrc"

# [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

# export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

# asdf config
[[ -s "$HOME/.asdf/asdf.sh" ]] && source "$HOME/.asdf/asdf.sh"
[[ -s "$HOME/.asdf/completions/asdf.bash" ]] && source "$HOME/.asdf/completions/asdf.bash"
export ASDF_INSTALL_PATH=$ASDF_DIR

# mix config to fix an asdf issue that cropped up
export MIX_HOME="$HOME/.mix"
export MIX_ARCHIVES="$MIX_HOME/archives"

# partial history search
if [[ $- == *i* ]]
then
    bind '"\e[A": history-search-backward' # up-arrow
    bind '"\e[B": history-search-forward'  # down-arrow
fi

# direnv hook
eval "$(direnv hook bash)"
source "$HOME/.cargo/env"

# environment vars config
source ~/.envconfig

[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

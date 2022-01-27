[[ $- == *i* ]] && echo "Running .pre-oh-my-bash.bashrc"

# platform info
pf="$(uname)"
if [ "$pf" = "Darwin" ]; then
  export PLATFORM="osx"
elif [ "$(expr substr $pf 1 5)" = "Linux" ]; then
  export PLATFORM="linux"
elif [ "$(expr substr $pf 1 10)" = "MINGW32_NT" ]; then
  export PLATFORM="windows"
else
  # this downcase requires bash 4+; you can pipe to tr '[:upper:]' '[:lower:]' instead
  export PLATFORM="${pf,,}"
fi
unset pf

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

# rust cargo hook
source "$HOME/.cargo/env"

# who am I?
# OK, $(basename $0) didn't work, so...
me=".pre-oh-my-bash.bashrc"

# Pull in path configuration
[[ $- == *i* ]] && echo -n "from $me: "
source ~/.pathconfig

# environment vars config
[[ $- == *i* ]] && echo -n "from $me: "
source ~/.envconfig

[[ -s "$HOME/.profile" ]] && [[ $- == *i* ]] && echo -n "from $me: "
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

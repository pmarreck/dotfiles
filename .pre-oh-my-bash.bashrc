$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo "Running .pre-oh-my-bash.bashrc" || echo -n "#"

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
if $INTERACTIVE_SHELL
then
    bind '"\e[A": history-search-backward' # up-arrow
    bind '"\e[B": history-search-forward'  # down-arrow
fi

# graceful dependency enforcement
# Usage: needs <executable> provided by <packagename>
needs() {
  local bin=$1
  shift
  command -v $bin >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

# rust cargo hook
source "$HOME/.cargo/env"

# who am I? (should work even when sourced from elsewhere, but only in Bash)
me=`basename ${BASH_SOURCE[0]}`

# Pull in path configuration
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo -n "from $me: "
source ~/.pathconfig

# direnv hook
eval "$(direnv hook bash)"

# environment vars config
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo -n "from $me: "
source ~/.envconfig

$DEBUG_SHELLCONFIG && [[ -s "$HOME/.profile" ]] && $INTERACTIVE_SHELL && echo -n "from $me: "
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

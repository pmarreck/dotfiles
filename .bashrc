# mute direnv constantly telling me what it's loading
export DIRENV_LOG_FORMAT=

# determine shell characteristics
# is this an interactive shell?
case "$-" in
  *i*)	export INTERACTIVE_SHELL=true ;;
  *)	export INTERACTIVE_SHELL=false ;;
esac
# is this a login shell?
# this is already set to false if .bash_profile ran (which implies it's a non-login shell)
export LOGIN_SHELL=${LOGIN_SHELL:-true};

if $INTERACTIVE_SHELL; then
  echo -n "i"
fi
if $LOGIN_SHELL; then
  echo -n "l"
fi

$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo "Running .bashrc" || echo -n "#"

# User configuration
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='code'
fi

# Compilation flags
# export ARCHFLAGS="-arch arm64"
export ARCHFLAGS="-arch $(uname -a | rev | cut -d ' ' -f 2 | rev)"
# note: "aarch64" may need to be mutated to "arm64" in some cases

# ssh
export SSH_KEY_PATH="~/.ssh/id_ed25519"

# Guix integration
[[ -s "$HOME/.guix-profile/etc/profile" ]] && source $HOME/.guix-profile/etc/profile

# platform info
pf="$(uname)"
if [ "$pf" = "Darwin" ]; then
  export PLATFORM="osx"
elif [ "$(expr substr $pf 1 5)" = "Linux" ]; then
  export PLATFORM="linux"
  # The following are 2 different ways to extract the value of a name=value pair input file
  # One depends on ripgrep being installed, the other on awk (which is installed by default on most linux distros)
  # You could also just source the file and then use the variable directly, but that pollutes the env
  export DISTRO="$(cat /etc/os-release | rg -r '$1' -o --color never '^NAME="?(.+)"?$')"
  export DISTRO_PRETTY="$(cat /etc/os-release | rg -r '$1' -o --color never '^PRETTY_NAME="?(.+)"?$')"
  export DISTRO_VERSION="$(cat /etc/os-release | awk -F= '$1=="VERSION_ID"{gsub(/(^["]|["]$)/,"",$2);print$2}')"
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
# Usage: needs <executable> ["provided by <packagename>"]
needs() {
  local bin=$1
  shift
  command -v $bin >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

# who am I? (should work even when sourced from elsewhere, but only in Bash)
me=`basename ${BASH_SOURCE[0]}`

# Pull in path configuration
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo -n "from $me: "
source ~/.pathconfig

# rust cargo hook and related environment dependencies
[[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
needs rustc "curl https://sh.rustup.rs -sSf | sh"
needs exa "cargo install exa"
needs tokei "cargo install --git https://github.com/XAMPPRocky/tokei.git tokei"

# direnv hook
eval "$(direnv hook bash)"

# for git paging:
needs delta cargo install git-delta

# environment vars config
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo -n "from $me: "
source ~/.envconfig

$DEBUG_SHELLCONFIG && [[ -s "$HOME/.profile" ]] && $INTERACTIVE_SHELL && echo -n "from $me: "
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile


# mcfly integration (access via ctrl-r)
needs mcfly "curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh | sudo sh -s -- --git cantino/mcfly" && eval "$(mcfly init bash)"

export DEBUG_SHELLCONFIG=false
export _TRACE_SOURCING=false

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
  printf "i"
fi
if $LOGIN_SHELL; then
  printf "l"
fi

$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo "Running .bashrc" || printf "#"

# User configuration
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
  unset VISUAL
else
  export EDITOR='code'
  export VISUAL='code'
fi

# Compilation flags
# export ARCHFLAGS="-arch arm64"
export ARCHFLAGS="-arch $(uname -a | rev | cut -d ' ' -f 2 | rev)"
# note: "aarch64" may need to be mutated to "arm64" in some cases

# ssh
export SSH_KEY_PATH="~/.ssh/id_ed25519"

# source a file relative to the current file
source_relative() {
  # _dir_name=`dirname "$0"` # doesn't work reliably
  _dir_name=`dirname "${BASH_SOURCE[0]}"` # works in bash but not POSIX compliant sh
  _temp_path=`cd "$_dir_name" && pwd`
  # $_TRACE_SOURCING && echo "Sourcing $temp_path/$1" >&2
  . "$_temp_path/$1"
  unset _dir_name _temp_path
}

# Define the source_relative_once function
# export _TRACE_SOURCING=true
source_relative_once() {
  local _file="$1"
  # Get the directory of the currently executing script
  # _dir=`dirname "$0"` # doesn't work reliably
  local _dir=`dirname "${BASH_SOURCE[0]}"` # works in bash but not POSIX compliant sh
  
  # Convert the relative path to an absolute path
  local _abs_path="$_dir/$_file"
  local _abs_dirname=`dirname "$_abs_path"`
  _abs_dirname=`cd "$_abs_dirname" && pwd`
  local _abs_filename=`basename "$_abs_path"`
  local _abs_path="$_abs_dirname/$_abs_filename"

  # test if _abs_path is empty
  if [ -z "$_abs_path" ]; then
    echo "Error in source_relative_once: \$_abs_path is blank" >&2
    return
  fi

  if [ ! -e "$_abs_path" ]; then
    echo "Error in source_relative_once: could not find file $_abs_path" >&2
    return
  fi

  # check if it is a softlink; if so, resolve it to the actual path
  if [ -L "$_abs_path" ]; then
    _abs_path=`realpath "$_abs_path"`
  fi

  # Check if the file has already been sourced
  if [[ " ${_SOURCED_FILES} " =~ " ${_abs_path} " ]]; then
    $_TRACE_SOURCING && echo "Already sourced \"$_abs_path\"" >&2
    return
  fi
  $_TRACE_SOURCING && local _debug_id=$RANDOM
  # If the file hasn't been sourced yet, source it and add it to the list of sourced files
  $_TRACE_SOURCING && echo "$_debug_id Sourcing (once?) \"$_abs_path\"" >&2
  $_TRACE_SOURCING && echo "$_debug_id prior to sourcing, _SOURCED_FILES is now \"${_SOURCED_FILES}\"" >&2
  if [ -z "$_SOURCED_FILES" ]; then
    export _SOURCED_FILES="$_abs_path"
  else
    export _SOURCED_FILES="$_abs_path $_SOURCED_FILES"
  fi
  source "$_abs_path"
  $_TRACE_SOURCING && echo "$_debug_id after sourcing \"$_abs_path\", _SOURCED_FILES is now \"${_SOURCED_FILES}\"" >&2
  return 0 # or else this exits nonzero and breaks other things
}

# Guix integration
[[ -s "$HOME/.guix-profile/etc/profile" ]] && source $HOME/.guix-profile/etc/profile

# Awk-ward! (see note below about "using the right awk"...)
export AWK=$(command -v gawk || command -v awk)

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
  export DISTRO_VERSION="$(cat /etc/os-release | $AWK -F= '$1=="VERSION_ID"{gsub(/(^["]|["]$)/,"",$2);print$2}')"
elif [ "$(expr substr $pf 1 10)" = "MINGW32_NT" ]; then
  export PLATFORM="windows"
else
  # this downcase requires bash 4+; you can pipe to tr '[:upper:]' '[:lower:]' instead
  export PLATFORM="${pf,,}"
fi
unset pf

# using the right awk is a PITA on macOS vs. Linux so let's ensure GNU Awk everywhere
is_gnu_awk=$($AWK --version | grep -q -m 1 'GNU Awk' && echo true || echo false)
[ "${PLATFORM}${AWK}" == "osxawk" ] && \
  [ "$is_gnu_awk" = "false" ] && \
  echo "WARNING: The awk on PATH is not GNU Awk on macOS, which may cause problems" >&2


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
me() {
  basename ${BASH_SOURCE[0]}
}

# Pull in path configuration
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && printf "from $(me): "
source_relative_once .pathconfig

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
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && printf "from $(me): "
source_relative_once .envconfig

$DEBUG_SHELLCONFIG && [[ -s "$HOME/.profile" ]] && $INTERACTIVE_SHELL && printf "from $(me): "
[[ -s "$HOME/.profile" ]] && source_relative_once .profile # Load the default .profile


# mcfly integration (access via ctrl-r)
needs mcfly "curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh | sudo sh -s -- --git cantino/mcfly" && eval "$(mcfly init bash)"

# starship
needs starship
eval "$(starship init bash)"

# line completion
# nope, doesn't work right with starship
# source ~/linecomp/linecomp.sh

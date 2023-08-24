#!/usr/bin/env bash
# shellcheck disable=SC2001

# So for debug switches, we will check whether they are even set using [[ -v VARNAME ]]
# because we do not want to pollute the env with the unnecessary presence of
# debug switches that are just set to false.
# But note that that only works in Bash 4+!
# For all other configs, just set to true/false as appropriate (but never blank!)
# export _TRACE_SOURCING=false
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
[[ -v DEBUG_PATHCONFIG ]] && echo "$PATH"

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

# graceful dependency enforcement
# Usage: needs <executable> ["provided by <packagename>"]
needs() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin="$1"
  shift
  command -v "$bin" >/dev/null 2>&1 || {
    printf "%s is required but it's not installed or in PATH; %s\n" "$bin" "$*" >&2
    return 1
  }
}

# User configuration
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='micro'
  unset VISUAL
else
  export EDITOR='code -g'
  export VISUAL='code -g'
fi

# go directly to edit of function source
edit_function() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local function_name="$1"
  local file="$2"
  local fl=$(grep -n "${function_name}() {" "$file" | cut -d: -f1)
  $EDITOR "$file":$fl
}

# Compilation flags
# export ARCHFLAGS="-arch arm64"
ARCHFLAGS="-arch $(uname -a | rev | cut -d ' ' -f 2 | rev)"
export ARCHFLAGS
# note: "aarch64" may need to be mutated to "arm64" in some cases

# ssh
export SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# most things should be sourced via source_relative... except source_relative itself
source "$HOME/dotfiles/bin/functions/source_relative.bash"

# Guix integration
[[ -s "$HOME/.guix-profile/etc/profile" ]] && source $HOME/.guix-profile/etc/profile

# Awk-ward! (see note below about "using the right awk"...)
AWK=$(command -v gawk || command -v awk)
export AWK

# using the right awk is a PITA on macOS vs. Linux so let's ensure GNU Awk everywhere
is_gnu_awk=$($AWK --version | grep -q -m 1 'GNU Awk' && echo true || echo false)
[ "${PLATFORM}${AWK}" == "osxawk" ] && \
  [ "$is_gnu_awk" = "false" ] && \
  echo "WARNING: The awk on PATH is not GNU Awk on macOS, which may cause problems" >&2

# platform info
pf="$(uname)"
if [ "$pf" = "Darwin" ]; then
  mac_os_version_number_to_name() {
    [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    # Get macOS version
    local version
    local distribution
    version=$(sw_vers -productVersion)
    # Map macOS version to distribution name
    case $version in
      15.*) distribution="<Please Update Me At ${BASH_SOURCE}:${LINENO}>" ;;
      14.*) distribution="Sonoma" ;;
      13.*) distribution="Ventura" ;;
      12.*) distribution="Monterey" ;;
      11.*) distribution="Big Sur" ;;
      10.15*) distribution="Catalina" ;;
      10.14*) distribution="Mojave" ;;
      10.13*) distribution="High Sierra" ;;
      10.12*) distribution="Sierra" ;;
      10.11*) distribution="El Capitan" ;;
      10.10*) distribution="Yosemite" ;;
      10.9*) distribution="Mavericks" ;;
      10.8*) distribution="Mountain Lion" ;;
      10.7*) distribution="Lion" ;;
      10.6*) distribution="Snow Leopard" ;;
      10.5*) distribution="Leopard" ;;
      *) distribution="Unknown" ;;
    esac
    export DISTRO_VERSION="$version"
    echo "$version ($distribution)"
  }
  export PLATFORM="osx"
  export DISTRO="macOS"
  export DISTRO_PRETTY="$DISTRO $(mac_os_version_number_to_name)"
elif [ "${pf:0:5}" = "Linux" ]; then
  export PLATFORM="linux"
  # The following are 2 different ways to extract the value of a name=value pair input file
  # One depends on ripgrep being installed, the other on awk (which is installed by default on most linux distros)
  # (edit: I converted the ripgrep to awk)
  # You could also just source the file and then use the variable directly, but that pollutes the env
  function distro() {
    [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    $AWK -F'=' '/^NAME=/{gsub(/"/, "", $2); print $2}' ${1:-/etc/os-release}
  }
  DISTRO=$(distro)
  export DISTRO
  function distro_pretty() {
    [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    $AWK -F'=' '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2}' ${1:-/etc/os-release}
  }
  DISTRO_PRETTY=$(distro_pretty)
  export DISTRO_PRETTY
  function distro_version() {
    [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    # shellcheck disable=SC2016
    $AWK -F= '$1=="VERSION_ID"{gsub(/(^["]|["]$)/,"",$2);print$2}' ${1:-/etc/os-release}
  }
  DISTRO_VERSION=$(distro_version)
  export DISTRO_VERSION
elif [ "${pf:0:10}" = "MINGW32_NT" ]; then
  export PLATFORM="windows"
  export DISTRO_PRETTY="...ok, why are you using windows?"
else
  # this downcase requires bash 4+; you can pipe to tr '[:upper:]' '[:lower:]' instead
  export PLATFORM="${pf,,}"
fi
unset pf

# # asdf config
# [[ -s "$HOME/.asdf/asdf.sh" ]] && source "$HOME/.asdf/asdf.sh"
# [[ -s "$HOME/.asdf/completions/asdf.bash" ]] && source "$HOME/.asdf/completions/asdf.bash"
# export ASDF_INSTALL_PATH=$ASDF_DIR

# # mix config to fix an asdf issue that cropped up
# export MIX_HOME="$HOME/.mix"
# export MIX_ARCHIVES="$MIX_HOME/archives"

# partial history search
if $INTERACTIVE_SHELL
then
    bind '"\e[A": history-search-backward' # up-arrow
    bind '"\e[B": history-search-forward'  # down-arrow
fi

# who am I? (should work even when sourced from elsewhere, but only in Bash)
me() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  basename "${BASH_SOURCE[0]}"
}

# Pull in path configuration
source_relative_once .pathconfig

needs exa "cargo install exa, or your package manager"
needs tokei "cargo install --git https://github.com/XAMPPRocky/tokei.git tokei, or your package manager"
needs micro "please install the micro terminal editor"
needs code "please install VSCode"

# for git paging:
needs delta "cargo install git-delta"

# environment vars config
source_relative_once .envconfig

# source posix profile
[[ -s "$HOME/.profile" ]] && source_relative_once .profile # Load the default .profile

# Load hooks
source $HOME/bin/apply-hooks || echo "Problem when sourcing $HOME/bin/apply-hooks"


[[ -v DEBUG_SHELLCONFIG ]] && echo "Exiting $(echo "${BASH_SOURCE[0]}" | sed "s|^$HOME|~|")"
[[ -v DEBUG_PATHCONFIG ]] && echo "$PATH" || :

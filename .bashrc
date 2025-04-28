#!/usr/bin/env bash
# shellcheck disable=SC2001

# So for debug switches, we will check whether they are even set using [[ -v VARNAME ]]
# because we do not want to pollute the env with the unnecessary presence of
# debug switches that are just set to false.
# But note that that only works in Bash 4+!
# For all other configs, just set to true/false as appropriate (but never blank!)
# export _TRACE_SOURCING=true
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

# determine shell characteristics
# is this an interactive shell? login shell?
# set LOGIN_SHELL and INTERACTIVE_SHELL here
shopt -q login_shell && LOGIN_SHELL=true || LOGIN_SHELL=false
[[ $- == *i* ]] && INTERACTIVE_SHELL=true || INTERACTIVE_SHELL=false

# most things should be sourced via source_relative... except source_relative itself
# if the function is not already defined, define it. use posix syntax for portability
# shellcheck disable=SC1090
[ "`type -t source_relative_once`" = "function" ] || . "$HOME/dotfiles/bin/functions/source_relative.bash"

# Pull in path configuration
source_relative_once .pathconfig

# Warp terminal seems to have nonstandard behavior and non-gnu sed breaks things
# so we are using this workaround:
# Set SED env var to first gnu sed found on PATH; otherwise warn
# Use [[ "$($candidate_sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]] to detect
# Find the first GNU sed in PATH if SED is unset
if [ -z ${SED+x} ]; then
  for candidate_sed in $(type -a -p gsed) $(type -a -p sed); do
    if [[ "$($candidate_sed --version 2>/dev/null | head -1)" =~ .*GNU.* ]]; then
      export SED=$candidate_sed
      break
    fi
  done
  # Warn if no GNU sed found
  if [ -z ${SED+x} ]; then
    echo "Warning from .bashrc: No GNU sed found in PATH. This may result in problems. Using system's default sed." >&2
    export SED=`which sed`
  fi
fi
# echo "SED in .bashrc:56 is: $SED"
# Awk-ward! (see note below about "using the right awk"...)
[ -z "${AWK+x}" ] && \
  export AWK=$(command -v frawk || command -v gawk || command -v awk)

[ "${DEBUG_SHELLCONFIG+set}" = "set" ] && echo "Entering $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")" || $INTERACTIVE_SHELL && $LOGIN_SHELL && append_dotfile_progress "rc"
[ "${DEBUG_PATHCONFIG+set}" = "set" ] && echo "$PATH"

# mute direnv constantly telling me what it's loading
export DIRENV_LOG_FORMAT=""

# graceful dependency enforcement
# Usage: needs <executable> ["provided by <packagename>"]
needs() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin="$1"
  shift
  command -v "$bin" >/dev/null 2>&1 || {
    printf "%s is required but it's not installed or in PATH; %s\n" "$bin" "$*" >&2
    return 1
  }
}

# blesh (ble.sh) config
# needs the system stty softlinked from ~/bin (or ~/dotfiles/bin) to temporarily be ahead of PATH for ble.sh to work
# _OLD_PATH="$PATH"
# PATH="$HOME/bin:$PATH"
# needs blesh-share "please install blesh" && source `blesh-share`/ble.sh
# $INTERACTIVE_SHELL && source `blesh-share`/ble.sh --noattach
# PATH="$_OLD_PATH"
# unset _OLD_PATH

# User configuration
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor with logic for local and remote sessions
unset VISUAL EDITOR
if [[ -n $SSH_CONNECTION ]]; then
  needs micro "please install the micro editor; defaulting to nano" && export EDITOR='micro' || export EDITOR='nano'
  unset VISUAL # note: this indicates to other tooling later on that we are not in a GUI context
else
  needs micro "please install the micro editor; defaulting to nano for EDITOR" && export EDITOR='micro' || export EDITOR='nano'
  needs code "please install the VSCode editor and commandline access for it" && export VISUAL='code' || export VISUAL="$EDITOR"
  needs windsurf "please install the Codeium Windsurf editor and commandline access for it" && export VISUAL='windsurf -g' || export VISUAL="${VISUAL:-$EDITOR}"
fi

choose_editor() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if [[ -n "$VISUAL" && -t 1 ]]; then
    # If VISUAL is set and the terminal is interactive
    $VISUAL $*
  elif [[ -n "$EDITOR" ]]; then
    # Otherwise, fall back to EDITOR if it's set
    $EDITOR $*
  else
    # Fallback to a sensible default, like vi or nano
    nano $*
  fi
}


# go directly to edit of function source
edit_function() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs rg "please install ripgrep!"
  local function_name="$1"
  # escape any question marks in the function name, some of mine end in one
  local function_name="${function_name//\?/\\?}"
  local file="$2"
  if [ -z "$function_name" ] || [ -z "$file" ]; then
    # Warn only once if not in Bash
    if [ -z "$EDIT_WARNED" ]; then
      echo "Warning: Edit functionality is only available in Bash, or invalid function/source reference." >&2
      EDIT_WARNED=1
    fi
    return 1
  fi
  # *** The following docs provided by ChatGPT4 ***
  # This line searches for Bash function definitions in the provided file using two potential patterns.
  # It then returns the line number of the last matched function definition.
  #
  # Components:
  # 1. `rg` is the ripgrep command, a fast text search tool.
  # 2. `-n` flag tells ripgrep to output line numbers for matches.
  # 3. `-e` flag is used to specify the regex patterns to search for.
  #
  # Patterns explained:
  # a. "${function_name} *\(\) *\{":
  #    This matches function definitions of the form "function_name()"
  #    followed by optional spaces and then a curly brace '{'.
  # b. "function +${function_name}(?: *\(\))? *\{":
  #    This matches the `function` keyword followed by one or more spaces,
  #    then the function name, optionally followed by a pair of parentheses (which can have spaces around),
  #    and then a curly brace '{'.
  #    The `(?: ... )?` construct is a non-capturing group with an optional match.
  #
  # 4. `tail -n1`: If multiple matches are found in the file, this will get the last one.
  # 5. `cut -d: -f1`: This extracts the line number from ripgrep's output.
  #    The delimiter (-d) is : (colon). -f1 means the first delimited field.
  #    ripgrep's output is of the form "linenumber:matched_line" due to the `-n` flag,
  #    so cutting on the colon in this way, gets the line number.
  local fl=$(rg -n -e "${function_name} *\(\) *\{" -e "function +${function_name}(?: *\(\))? *\{" "$file" | tail -n1 | cut -d: -f1)
  choose_editor "${file}:${fl}"
}

# Silence function - runs a command silently but preserves exit code
# (Note that there is another function called "success?" in functions/utility_functions.bash
# that does the same thing.)
silence() {
  "$@" >/dev/null 2>&1
  return $?
}

# control globbing/shell expansion on a case-by-case basis
expand() {
  # Test function for expand
  _test_expand() {
    local verbose=${EXPAND_TEST_VERBOSE:-false}
    local fail_count=0
    local test_name=""
    local expected=""
    local actual=""

    # Helper function to run a test and check the result
    _run_test() {
      test_name="$1"
      expected="$2"
      shift 2

      if $verbose; then
        echo -n "Running test: $test_name... "
      fi

      # Capture the actual output
      actual=$("$@")

      # Compare with expected output
      if [[ "$actual" == "$expected" ]]; then
        if $verbose; then
          green_text "PASS"
          echo
        fi
      else
        if $verbose; then
          red_text "FAIL"
          echo
          red_text "  Expected: '$expected'"
          echo
          red_text "  Actual:   '$actual'"
          echo
        fi
        ((fail_count++))
      fi
    }

    # Create test files
    touch test1.jpg test2.jpg "test with spaces.jpg"

    # Test 1: Direct pattern expansion
    _run_test "Direct pattern expansion" \
      "test\ with\ spaces.jpg test1.jpg test2.jpg " \
      expand "test*.jpg"

    # Test 2: Command with pattern
    _run_test "Command with pattern" \
      "test1.jpg test2.jpg test with spaces.jpg" \
      expand echo "test*.jpg"

    # Test 3: Command with multiple patterns
    _run_test "Command with multiple patterns" \
      "test1.jpg test1.jpg test2.jpg test with spaces.jpg" \
      expand echo "test1.jpg" "test*.jpg"

    # Test 4: Pattern with spaces
    _run_test "Pattern with spaces" \
      "test\\ with\\ spaces.jpg " \
      expand "test with*.jpg"

    # Test 5: Non-matching pattern
    _run_test "Non-matching pattern" \
      "nonexistent\\*.jpg " \
      expand "nonexistent*.jpg"

    # Test 6: Command with non-matching pattern
    _run_test "Command with non-matching pattern" \
      "nonexistent*.jpg" \
      expand echo "nonexistent*.jpg"

    # Clean up test files
    rm test1.jpg test2.jpg "test with spaces.jpg"

    # Final summary
    if $verbose; then
      echo ""
      if [[ $fail_count -eq 0 ]]; then
        green_text "All tests passed successfully!"
        echo
      else
        red_text "$fail_count test(s) failed."
        echo
      fi
    fi

    return $fail_count
  }

  # Help function
  _show_help() {
    cat << EOF
expand: A utility for controlled glob expansion

USAGE:
  expand PATTERN                   Expand a glob pattern and print results
  expand COMMAND [ARG...]          Run a command with expanded arguments
  expand --test                    Run self-tests
  expand --help                    Show this help message

EXAMPLES:
  expand "*.jpg"                   Expand and print all jpg files
  expand ls -la "*.jpg"            Run ls -la with expanded jpg files
  expand jpegxl --lossless "*.jpg" Run jpegxl with expanded jpg files

DESCRIPTION:
  The expand function provides controlled glob expansion even when
  globbing is disabled (set -f). It preserves spaces in filenames
  and properly quotes results for shell consumption.

  When used with a command, it expands any glob patterns in the arguments
  before passing them to the command. If a pattern doesn't match any files,
  it's passed as-is to the command.
EOF
  }

  # Check for special arguments
  if [[ $# -eq 0 || "$1" == "--help" ]]; then
    _show_help
    return 0
  fi

  if [[ "$1" == "--test" ]]; then
    # Skip tests unless explicitly requested
    if [[ "${EXPAND_TEST_VERBOSE:-false}" != "true" ]]; then
      return 0
    fi

    echo "Testing expand function..."
    _test_expand
    return $?
  fi

  # Store original globbing state and nullglob setting
  local glob_disabled nullglob_set
  [[ -o noglob ]] && glob_disabled=true || glob_disabled=false
  [[ -o nullglob ]] && nullglob_set=true || nullglob_set=false

  # Enable globbing temporarily
  set +f

  local first_arg="$1"

  # Detect if first argument is an expansion (contains *, ?, [)
  if [[ "$first_arg" == *[\*\?\[]* ]]; then
    debug "First argument is an expansion: $first_arg"

    # Enable nullglob for direct pattern expansion
    shopt -s nullglob

    # For patterns with spaces, use find instead of bash's built-in globbing
    if [[ "$first_arg" == *" "* ]]; then
      debug "Pattern contains spaces, using find"
      local expanded=()
      while IFS= read -r -d $'\0' file; do
        # Remove ./ prefix if present
        file="${file#./}"
        expanded+=("$file")
      done < <(find . -maxdepth 1 -name "$first_arg" -print0 2>/dev/null)
    else
      # Use bash's built-in globbing for patterns without spaces
      local expanded=($first_arg)
    fi

    # If no matches found, keep the original pattern
    if [[ ${#expanded[@]} -eq 0 ]]; then
      debug "No matches found for pattern: $first_arg"
      expanded=("$first_arg")
    else
      debug "Found ${#expanded[@]} matches for pattern: $first_arg"
    fi

    # Print expanded filenames safely, properly quoted for shell consumption
    for item in "${expanded[@]}"; do
      builtin printf "%q " "$item"
    done
    echo

    # Restore original settings
    $glob_disabled && set -f
    $nullglob_set || shopt -u nullglob
    return
  fi

  # Detect if first argument is an executable command
  if silence command -v "$first_arg"; then
    local retcode
    debug "First argument is an executable command: $first_arg"

    # For commands, we want to expand any glob patterns in the arguments
    shift
    local expanded_args=()

    # Process each argument
    for arg in "$@"; do
      if [[ "$arg" == *[\*\?\[]* ]]; then
        debug "Expanding glob pattern: $arg"

        # For command arguments, we want to keep the pattern if no matches
        # so DON'T enable nullglob here
        shopt -u nullglob

        # Save the original pattern before expansion
        local original_pattern="$arg"

        # Use find to expand the pattern reliably
        local arg_expanded=()
        while IFS= read -r -d $'\0' file; do
          # Remove ./ prefix if present
          file="${file#./}"
          arg_expanded+=("$file")
        done < <(find . -maxdepth 1 -name "$original_pattern" -print0 2>/dev/null)

        debug "Found ${#arg_expanded[@]} matches for pattern: $original_pattern"

        # If no matches found, keep the original pattern
        if [[ ${#arg_expanded[@]} -eq 0 ]]; then
          debug "No matches found, keeping original pattern: $original_pattern"
          expanded_args+=("$original_pattern")
        else
          debug "Adding expanded arguments: ${arg_expanded[*]}"
          expanded_args+=("${arg_expanded[@]}")
        fi
      else
        # Not a glob pattern, add as is
        debug "Adding non-glob argument: $arg"
        expanded_args+=("$arg")
      fi
    done

    debug "Final command: $first_arg ${expanded_args[*]}"

    # Execute command with expanded args in a subshell
    # The subshell gets replaced by exec, but the parent shell continues
    (exec "$first_arg" "${expanded_args[@]}")
    retcode=$?

    # Restore original settings
    $glob_disabled && set -f
    $nullglob_set || shopt -u nullglob
    return $retcode
  fi

  # Otherwise, assume it's a filename and print safely, properly quoted
  debug "First argument is a filename: $first_arg"

  # Enable nullglob for consistent behavior
  shopt -s nullglob

  for item in "$@"; do
    builtin printf "%q " "$item"
  done
  echo

  # Restore original settings
  $glob_disabled && set -f
  $nullglob_set || shopt -u nullglob
}

# Run tests for expand function when dotfiles change
if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  # Define a wrapper function that returns the test result
  _run_expand_tests() {
    # Only show test output if explicitly requested via EXPAND_TEST_VERBOSE=true
    # Test will still run silently to ensure functionality is correct
    EXPAND_TEST_VERBOSE=${EXPAND_TEST_VERBOSE:-false} expand --test
    return $?
  }

  # Source the test reporter if it's not already available
  if ! type run_test_suite &>/dev/null; then
    if [ -f "$HOME/dotfiles/bin/functions/test_reporter.bash" ]; then
      source "$HOME/dotfiles/bin/functions/test_reporter.bash"
    fi
  fi

  # Run the tests using the test suite runner if available
  if type run_test_suite &>/dev/null; then
    run_test_suite "expand" : _run_expand_tests
  else
    # Fallback to direct execution
    _run_expand_tests
    if [ $? -eq 0 ]; then
      $EXPAND_TEST_VERBOSE && echo "expand function tests passed"
    else
      # Always show errors, even in non-verbose mode
      echo "expand function tests failed with $? failures"
    fi
  fi
fi

# Utility functions
# Compilation flags
# export ARCHFLAGS="-arch arm64"
ARCHFLAGS="-arch $(uname -a | rev | cut -d ' ' -f 2 | rev)"
export ARCHFLAGS
# note: "aarch64" may need to be mutated to "arm64" in some cases

# ssh
export SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# Guix integration
[[ -s "$HOME/.guix-profile/etc/profile" ]] && source $HOME/.guix-profile/etc/profile

is_nix_darwin() {
  [ -f "/etc/nix/nix.conf" ] && [ "$(uname)" = "Darwin" ]
}
export -f is_nix_darwin

# platform info
case $OSTYPE in
  darwin*)
    mac_os_version_number_to_name() {
      [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
      # Get macOS version
      local version
      local distribution
      version=$(sw_vers -productVersion)
      # Map macOS version to distribution name
      case $version in
        16.*) distribution="<Please Update Me At ${BASH_SOURCE}:${LINENO}>" ;;
        15.*) distribution="Sequoia" ;;
        14.*) distribution="Sonoma" ;;
        13.*) distribution="Ventura" ;;
        12.*) distribution="Monterey" ;;
        11.*) distribution="Big Sur" ;;
        10.15*) distribution="Catalina" ;;
        10.14*) distribution="Mojave" ;; # last version to support 32-bit Mac apps
        10.13*) distribution="High Sierra" ;;
        10.12*) distribution="Sierra" ;;
        10.11*) distribution="El Capitan" ;;
        10.10*) distribution="Yosemite" ;;
        10.9*) distribution="Mavericks" ;;
        10.8*) distribution="Mountain Lion" ;;
        10.7*) distribution="Lion" ;;
        10.6*) distribution="Snow Leopard" ;;
        10.5*) distribution="Leopard" ;;
        10.4*) distribution="Tiger" ;;
        10.3*) distribution="Panther" ;;
        10.2*) distribution="Jaguar" ;;
        10.1*) distribution="Puma" ;;
        10.0*) distribution="Cheetah" ;;
        *) distribution="Unknown" ;;
      esac
      export DISTRO_VERSION="$version"
      echo "$version ($distribution)"
    }
    export PLATFORM="osx"
    export DISTRO="macOS"
    export DISTRO_PRETTY="$DISTRO $(mac_os_version_number_to_name)"
    ;;
  linux*)
    export PLATFORM="linux"
    # The following are 2 different ways to extract the value of a name=value pair input file
    # One depends on ripgrep being installed, the other on awk (which is installed by default on most linux distros)
    # (edit: I converted the ripgrep to awk)
    # You could also just source the file and then use the variable directly, but that pollutes the env
    function distro() {
      [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
      $AWK -F'=' '/^NAME=/{gsub(/"/, "", $2); print $2}' ${1:-/etc/os-release}
    }
    DISTRO=$(distro)
    export DISTRO
    function distro_pretty() {
      [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
      $AWK -F'=' '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2}' ${1:-/etc/os-release}
    }
    DISTRO_PRETTY=$(distro_pretty)
    export DISTRO_PRETTY
    function distro_version() {
      [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
      # shellcheck disable=SC2016
      $AWK -F= '$1=="VERSION_ID"{gsub(/(^["]|["]$)/,"",$2);print$2}' ${1:-/etc/os-release}
    }
    DISTRO_VERSION=$(distro_version)
    export DISTRO_VERSION
    ;;
  msys*|cygwin*|mingw*)
    export PLATFORM="windows"
    export DISTRO_PRETTY="...ok, why are you using windows?"
    ;;
  *)
    # this downcase requires bash 4+; you can pipe to tr '[:upper:]' '[:lower:]' instead
    export PLATFORM="$OSTYPE"
    ;;
esac

if [ "$AWK" = "" ]; then
  export AWK=$(command -v frawk || command -v gawk || command -v awk)
fi
# echo "AWK in .bashrc:258 is: $AWK"
# using the right awk is a PITA on macOS vs. Linux so let's ensure GNU Awk everywhere
is_gnu_awk=$($AWK --version | grep -q -m 1 'GNU Awk' && echo true || echo false)
[ "${PLATFORM}$(basename $AWK)" == "osxawk" ] && \
  $is_gnu_awk && \
  echo "WARNING: The awk on PATH is not GNU Awk on macOS, which may cause problems" >&2

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
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  basename -- "${BASH_SOURCE[0]}"
}

# zoxide integration
needs zoxide "get zoxide via cargo or your package manager" && eval "$(zoxide init --cmd cd --hook pwd bash)"

needs eza "cargo install eza, or your package manager"
needs tokei "cargo install --git https://github.com/XAMPPRocky/tokei.git tokei, or your package manager"
needs micro "please install the micro terminal editor"
needs code "please install VSCode"

# for git paging:
needs delta "cargo install git-delta"

# ble.sh
# Uncomment when the following fix makes it to mainstream branches:
# https://github.com/jeffkreeftmeijer/system/commit/e54f0755f3b5c9f8888ac06bd1bb92d9ff52e709
# needs blesh-share "please install ble.sh > v0.4"
# source `blesh-share`/ble.sh

# environment vars config
source_relative_once .envconfig

# source posix profile
[[ -s "$HOME/.profile" ]] && source_relative_once .profile # Load the default .profile

# Load hooks (skip during rehash to avoid issues)
if [[ "${REHASHING:-false}" != "true" ]]; then
  if [[ -f "$HOME/bin/apply-hooks" ]]; then
    source "$HOME/bin/apply-hooks" || echo "Problem when sourcing $HOME/bin/apply-hooks"
  fi
fi

# aliases- source these on every interactive shell because they do not inherit
$INTERACTIVE_SHELL && . "$HOME/dotfiles/bin/aliases.sh"

# Keep globbing/shell expansion off by default due to possible unexpected behavior
set -f

# Turn history expansion off because I like my exclamations unadulterated
# (and never use history expansion anyway)
# TODO: function to turn on history expansion temporarily, like what I do
# with the expand function to handle globbing
set +H

# [ -n "$DEBUG_SHELLCONFIG" ] && echo "sourced aliases.sh"

# activate ble.sh/blesh
# [[ ! ${BLE_VERSION-} ]] || ble-attach

[ -n "${DEBUG_SHELLCONFIG}" ] && echo "Entering $(echo "${BASH_SOURCE[0]}" | $SED "s|^$HOME|~|")" || $INTERACTIVE_SHELL && $LOGIN_SHELL && append_dotfile_progress "rc"
[ -n "${DEBUG_PATHCONFIG}" ] && echo "$PATH" || :

# Added by LM Studio CLI (lms)
# export PATH="$PATH:/Users/pmarreck/.cache/lm-studio/bin"
# End of LM Studio CLI section


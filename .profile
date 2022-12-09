#!/usr/bin/env bash
$DEBUG_SHELLCONFIG && $INTERACTIVE_SHELL && echo "Running .profile" || echo -n "#"

$INTERACTIVE_SHELL && echo " Platform: $PLATFORM"

# graceful dependency enforcement
# Usage: needs <executable> provided by <packagename>
>/dev/null declare -F needs || needs() {
  local bin=$1
  shift
  command -v $bin >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

# config for Visual Studio Code
if [ "$PLATFORM" = "osx" ]; then
  code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode --args $* ;}
  pipeable_code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode -f ;}
  export PIPEABLE_EDITOR='pipeable_code'
fi
# export EDITOR='code' # already set in .bashrc

# If you hate noise
# set bell-style visible

# for assertions everywhere!

# add hex command to dump hex from stdin or args (note that hexdump also exists)
# usage: echo "peter" | hex
# or: hex peter
hex() {
  if [ -z "$1" ]; then # if no arguments
    # The following exits code 0 if stdin not empty; 1 if empty; does not consume any bytes.
    # This may only be a Bash-ism, FYI. Not sure if it's shell-portable.
    # read -t 0
    # retval=${?##1} # replace 1 with blank so it falses correctly if stdin is empty
    if read -t 0; then
      xxd -pu  # receive piped input from stdin
    else # if stdin is empty AND no arguments
      echo "Usage: hex <string>"
      echo "       (or pipe something to hex)"
      echo "This function is defined in ${BASH_SOURCE[0]}"
    fi
  else # if arguments
    echo -ne "$@" | xxd -pu # pipe all arguments to xxd
  fi
}

# usage: assert [condition] [message]
# if condition is false, print message and exit
assert() {
  local arg1="$1"
  local comp="$2"
  local arg2="$3"
  local message="$4"
  arg1_enc=$(hex "$arg1")
  arg2_enc=$(hex "$arg2")
  case $comp in
    = | == )
      comparison_encoded="[ \"$arg1_enc\" $comp \"$arg2_enc\" ]"
      comparison="[ \"$arg1\" $comp \"$arg2\" ]"
    ;;
    != | !== )
      comparison_encoded="[ \"$arg1_enc\" \!= \"$arg2_enc\" ]"
      comparison="[ \"$arg1\" \!= \"$arg2\" ]"
    ;;
    =~ ) # can't do encoded regex comparisons, so just do a plaintext comparison
      comparison_encoded="[[ \"$arg1\" =~ $arg2 ]]"
      comparison="[[ \"$arg1\" =~ $arg2 ]]"
    ;;
    !=~ | !~ )
      comparison_encoded="[[ ! \"$arg1\" =~ $arg2 ]]"
      comparison="[[ ! \"$arg1\" =~ $arg2 ]]"
    ;;
    * ) 
      echo "Unknown comparison operator: $comp" >&2
      return 1
    ;;
  esac
  if eval "$comparison_encoded"; then
    return 0
  else
    # These values (BASH_SOURCE and BASH_LINENO) seem valid when triggered in my dotfiles, but not from my shell.
    # Not sure how to fix yet.
    echo "Assertion failed: \"$arg1\" $comp \"$arg2\" @ ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"
    [ -n "$message" ] && echo $message
    return 1
  fi
}

assert "$(hex "peter")" == "7065746572" "hex function should encode strings to hex"

# Pager config (ex., for git diff output)
#E=quit at first EOF
#Q=no bell
#R=pass through raw ansi so colors work
#X=no termcap init
export LESS="-EQRX"

# ulimit. to see all configs, run `ulimit -a`
# ulimit -n 10000

####### Aliases
#what most people want from od (hexdump)
alias hd='od -Ax -tx1z -v'
#just list directories
# alias lld='ls -lUd */'
# alias .='pwd' # disabled because it breaks scripts that use '.' instead of 'source'
alias ..='cd ..'
alias cd..='cd ..'
alias cdwd='cd `pwd`'
alias cwd='echo $cwd'
alias files='find \!:1 -type f -print'      # files x => list files in x
# the following is already included in oh-my-bash
# alias ff='find . -name \!:1 -print'      # ff x => find file named x
# the following doesn't seem to work, and should be a function anyway, even if aliases can take arguments
# alias line='sed -n '\''\!:1 p'\'' \!:2'    # line 5 file => show line 5 of file
# alias l='ls -lGaph'
# brew install exa
alias l='exa --long --header --sort=name --all'
alias l1='l --git -@ --icons'
alias l2='l1 --tree --level=2'
alias l3='l1 --tree --level=3' #--extended 
alias l4='l1 --tree --level=4'
# alias ll='ls -lagG \!* | more'
# alias term='set noglob; unset TERMCAP; eval `tset -s -I -Q - \!*`'
# alias rehash='hash -r'
alias rehash='source "$HOME/.bash_profile"'
# alias rehash='source ~/.profile'
# alias word='grep \!* /usr/share/dict/web2' # Grep thru dictionary
if [ "$PLATFORM" = "osx" ]; then
  alias tophog='top -ocpu -s 3'
else # linux
  alias tophog='top -o %CPU -d 3'
fi

#alias wordcount=(cat \!* | tr -s '\''  .,;:?\!()[]"'\'' '\''\012'\'' |' \
#                'cat -n | tail -1 | awk '\''{print $1}'\'')' # Histogram words
# alias js='java org.mozilla.javascript.tools.shell.Main'
scr() {
  needs screen
  screen -r
}
alias p='ping www.yahoo.com'
alias pp='ping -A -i 5 8.8.4.4' #Ping the root google nameserver every 5 seconds and beep if no route
alias t='btop'
# alias tu='top -ocpu -Otime'
alias bye='logout'

# The current thing(s) I'm working on
alias mpnetwork='cd ~/Documents/mpnetwork*'
# alias simpaticio='cd ~/Documents/simpaticio'
alias work=mpnetwork

# alias ss='script/server'
# alias sc='script/console'
# alias rc='rails console'

# network crap (OS X only)
if [ "$PLATFORM" = "osx" ]; then
  alias killdns='sudo killall -HUP mDNSResponder'
fi

# why is grep dumb?
# alias grep='egrep'

# elixir/phoenix gigalixir prod deploy command
needs git
alias deploy='git push gigalixir master'

# log all terminal output to a file
alias log='/usr/bin/script -a ~/Terminal.log; source ~/.bash_profile'

# This was inevitable.
needs curl
needs jq
needs figlet
alias btc='curl -s https://www.bitstamp.net/api/ticker/ | jq ".last | tonumber" | figlet -kcf big'

# from https://twitter.com/liamosaur/status/506975850596536320
# this just runs the previously-entered command as sudo
alias fuck='sudo $(history -p \!\!)'

### Different ways to print a "beep" sound. I settled on the last one. It's shell-agnostic.
# From http://stackoverflow.com/questions/3127977/how-to-make-the-hardware-beep-sound-in-mac-os-x-10-6
# alias beep='echo -en "\007"'
# alias beep='printf "\a"'
alias beep='tput bel'

# forget curl vs wget; just get a URL, follow any redirects, and output it to stdout, reliably
alias get='wget -q -O - --'

alias consoleconfig='code $WEZTERM_CONFIG_FILE'

# forkbomb!
# alias forkbomb=':(){ :|:& };:'

# provide a universal "open" on linux to open a path in the file manager
if [ "$PLATFORM" = "linux" ]; then
  open() {
    # if no args, open current dir
    xdg-open "${1:-.}"
  }
fi

# get nvidia driver version on linux
nvidia() {
  needs nvidia-smi # from nvidia-cuda-toolkit
  needs rg # ripgrep
  nv_version=$(nvidia-smi | rg -r '$1' -o --color never 'Driver Version: ([0-9]{3}\.[0-9]{1,3}\.[0-9]{1,3})')
  case $1 in
    "--version")
      echo $nv_version
      ;;
    "")
      echo -ne "Driver: "
      echo $nv_version
      echo "Devices: "
      lspci | rg -r '$1' -o --color never 'VGA compatible controller: NVIDIA Corporation [^ ]+ (.+)$'
      ;;
    *)
      echo "Usage: nvidia [--version]"
      echo "The --version flag prints the driver version only."
      echo "This function is defined in ${BASH_SOURCE} ."
      ;;
  esac
}

# Get the zfs compression savings for every file or directory in this directory
# Note: Currently borked. Need to fix
zfs_compsavings() {
  echo "actual compressed savings  filename"
  echo "------ ---------- -------- --------"
  for i in `pwd`/* ; do
    actualsize=`du --block-size=1 -s "$i" | awk '{print $1}'`
    # some files are 0 bytes, and we don't like dividing by zero
    if [ $actualsize = "0" ]; then
      actualsize="1"
    fi
    actualsize_h=`SIZE=1K du -sh "$i" | awk '{print $1}'`
    compressedsize=`du --block-size=1 --apparent-size -s "$i" | awk '{print $1}'`
    compressedsize_h=`du -h --apparent-size -s "$i" | awk '{print $1}'`
    ratio=`echo "scale = 2; (1 - ($compressedsize / $actualsize)) * 100" | bc -l`
    file=`basename "$i"`
    printf "%6s %10s %8s %s\n" "${actualsize_h}" "${compressedsize_h}" "${ratio}%" "$file"
  done
}

# because I always forget how to do this...
dd_example() {
  echo "sudo dd if=/home/pmarreck/Downloads/TrueNAS-SCALE-22.02.4.iso of=/dev/sdf bs=1M oflag=sync status=progress"
}

# make it easier to write ISO's to a USB key:
write_iso() {
  sudo dd if="$1" of="$2" bs=1M oflag=sync status=progress
}

# copy an entire directory showing progress
# example: cpv ~/Documents /mnt/Backup
# This copies the entire ~/Documents directory to /mnt/Backup/Documents, showing progress
cpv() {
  local real_source_path="$(realpath "$1")"
  # ensure real_source_path is a real directory or file
  if [ ! -e "$real_source_path" ]; then
    echo "Error: $1 does not exist" 1>&2
    return 1
  fi
  local sourcedir="$(dirname "$real_source_path")"
  local destdir="$(realpath "$2")"
  # ensure destdir is a directory that exists
  if [ ! -d "$destdir" ]; then
    echo "Destination directory $destdir does not exist." 1>&2
    return 1
  fi
  local size_bytes=$(du -sb "$real_source_path" | awk '{print $1}')
  local size_metadata=$(du -s --inodes "$real_source_path" | awk '{print $1}')
  local size_total=$(($size_bytes + $size_metadata))
  local filename="$(basename "$real_source_path")"
  pushd "$sourcedir" > /dev/null
  tar cf - "$filename" | pv -c -s $size_total | tar xf - -C "$destdir"
  popd > /dev/null
}

# do simple math in the shell
# example: calc 2+2
# note that 'calc 4 * 23' will fail due to globbing, but 'calc 4*23' or 'calc "4 * 23"' will work
# calc "define fac(x) { if (x == 0) return (1); return (fac(x-1) * x); }; fac(5)"
calc() {
  local scale=${SCALE:-10}
  # echo "$*"
  # ok so bc *requires* a newline after an open brace, but it *doesn't* require a newline before a close brace
  # so we have to do this weird thing where we replace all newlines with spaces, then replace all spaces after an open brace with a newline
  local bcscript=$(echo -e "$*" | sed 's/\n+/ /g' | sed 's/{\s*/{\n/g' | sed 's/} *;?/}\n/g' | sed 's/;/\n/g')
  [ -n "$DEBUG" ] && echo -e "string received by calc:\n$bcscript" >&2
  echo -e "scale=${scale}\n$bcscript" | bc -l
}

assert "$(calc 2*4)" == 8 "simple calculations with calc should work"
assert "$(calc "define fac(x) { if (x == 0) return (1); return (fac(x-1) * x); }; fac(5)")" == 120 "recursive functions with calc should work"

source $HOME/bin/encrypt_decrypt.sh

source $HOME/bin/randompass.sh

# GPG configuration to set up in-terminal challenge-response
export GPG_TTY=`tty`

# which hack, so it also shows defined aliases and functions that match
# where() {
#   type_out=`type "$@"`;
#   if [ ! -z "$type_out" ]; then
#     echo "$type_out";
#   else
#     /usr/bin/env which $@;
#   fi
# }
# Note: Superseded by "define" function below

source $HOME/bin/define.sh
# and also alias it to d because that's convenient
# define d # it's already defined somewhere, I know not where!
alias def=define

# elixir and js lines of code count
# removes blank lines and commented-out lines
elixir_js_loc() {
  git ls-files | egrep '\.erl|\.exs?|\.js$' | xargs cat | sed '/^$/d' | sed '/^ *#/d' | sed '/^ *\/\//d' | wc -l
}

# universal edit command, points back to your defined $EDITOR
# note that there is an "edit" command in Ubuntu that I told to fuck off basically
edit() {
  $EDITOR "$@"
}

# gem opener, if you have not yet moved on from Ruby to Elixir :)
open_gem() {
  $EDITOR `bundle show $1`
}

# thar be dragons
dragon() {
  # first store the escape code for the ANSI color
  local esc=$(printf '\033')
  # set foreground text color to green
  echo -e "${esc}[0;32m"
  # print the dragon, prefacing and suffixing runs of # with a background ansi mode of green
  cat <<-'EOD' | sed -E "s/(#+)/${esc}[42m\1${esc}[49m/g"
                    ___====-_  _-====___
              _--~~~#####//      \\#####~~~--_
           _-~##########// (    ) \\##########~-_
          -############//  :\^^/:  \\############-
        _~############//   (@::@)   \\############~_
       ~#############((     \\//     ))#############~
      -###############\\    (^^)    //###############-
     -#################\\  / "" \  //#################-
    -###################\\/      \//###################-
   _#/:##########/\######(   /\   )######/\##########:\#_
   :/ :#/\#/\#/\/  \#/\##\  :  :  /##/\#/  \/\#/\#/\#: \:
   "  :/  V  V  "   V  \#\: :  : :/#/  V   "  V  V  \:  "
      "   "  "      "   \ : :  : : /   "      "  "   "
EOD
  echo -e "${esc}[0m"
}

# mandelbrot set
# from https://bruxy.regnet.cz/web/linux/EN/mandelbrot-set-in-bash/
# (fixed point version for speed. also because fuck floating point math)
mandelbrot() {
  p=\>\>14 e=echo\ -ne\  S=(S H E L L) I=-16384 t=/tmp/m$$; for x in {1..13}; do \
  R=-32768; for y in {1..80}; do B=0 r=0 s=0 j=0 i=0; while [ $((B++)) -lt 32 -a \
  $(($s*$j)) -le 1073741824 ];do s=$(($r*$r$p)) j=$(($i*$i$p)) t=$(($s-$j+$R));
  i=$(((($r*$i)$p-1)+$I)) r=$t;done;if [ $B -ge 32 ];then $e\ ;else #---::BruXy::-
  $e"\E[01;$(((B+3)%8+30))m${S[$((C++%5))]}"; fi;R=$((R+512));done;#----:::(c):::-
  $e "\E[m\E(\r\n";I=$((I+1311)); done|tee $t;head -n 12 $t| tac  #-----:2 O 1 O:-  
}

source $HOME/bin/clock.bash

# get current weather, output as big ASCII art
weather() {
  needs curl
  needs jq
  needs bc
  needs figlet # note that on ubuntu derivatives, this is shortcutted by default to "toilet"? Um, no. So check that.
  if [ -z "$OPENWEATHERMAP_APPID" ]; then
    echo "OPENWEATHERMAP_APPID is not set. Get an API key from http://openweathermap.org/appid and set it in your environment."
    return 1
  fi
  # lat and lon are set for port washington, ny
  # look them up at: http://www.latlong.net/
  temp=`curl -s "http://api.openweathermap.org/data/2.5/weather?lat=40.82658&lon=-73.68312&appid=$OPENWEATHERMAP_APPID" | jq .main.temp`
  # echo "temp in kelvin is: $temp"
  temp=$(bc <<< "$temp*9/5-459.67") # convert from kelvin to F
  echo "$temp F" | figlet -kcf big
}
# my openweathermap key did not work after I created it... time delay?
# EDIT: Works now
# But returns Kelvin. Don't have time to figure out F from K in Bash using formula F = K * 9/5 - 459.67
# EDIT 2: Figured that out

# get the current FANCY (not just ANSI🤣) weather. wttr.in has tons of URL options, check out their site:
# https://github.com/chubin/wttr.in
weatherfancy() {
  curl wttr.in
}

# crypto market data. can pass a symbol in or just get the current overall market data
crypto() {
  curl rate.sx/$1
}

# am I the only one who constantly forgets the correct order of arguments to `ln`?
lnwtf() {
  echo 'ln -s path_of_thing_to_link_to [name_of_link]'
  echo '(If you omit the latter, it puts a basename-named link in the current directory)'
  echo "This function is defined in $BASH_SOURCE"
}

# add otp --version command
otp() {
  needs erl
  case $1 in
    "--version")
      erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell
      ;;
    *)
      echo "Usage: otp --version"
      echo "This function is defined in $BASH_SOURCE"
      ;;
  esac
}

# Use LLVM-GCC4.2 as the c compiler
# CC='`xcode-select -print-path`/usr/bin/llvm-gcc-4.2 make'

# requires homebrew's apple-gcc42 installed
# export CC=/usr/local/bin/gcc-4.2
# export GCC=/usr/local/bin/gcc-4.2
# export CXX=/usr/local/bin/gcc-4.2

# Use clang as the c compiler
# CC='/Developer/usr/bin/clang'
# export CC=/opt/local/bin/clang
# export CXX=/opt/local/bin/clang++

# Sexy man pages. Opens a postscript version in Preview.app on OS X or evince on Linux
if [ "$PLATFORM" = "osx" ]; then
  pman() { man -t "$@" | open -f -a Preview; }
elif [ "$PLATFORM" = "linux" ]; then
  # unfortunately this is a little grosser on linux, requiring a tempfile
  pman() {
    needs evince provided by evince package
    tmpfile=$(mktemp --suffix=.pdf /tmp/$1.XXXXXX)
    man -Tpdf "$@" >> $tmpfile 2>/dev/null
    evince $tmpfile
  }
fi

# Who is holding open this damn port or file??
# usage: portopen 3000
portopen() {
	sudo lsof -P -i ":${1}"
}
fileopen() {
	sudo lsof "${1}"
}

# Print a string num times. Comes from Perl apparently.
# usage: x string num
x() {
  for i in $(seq 1 $2); do printf "%s" "$1"; done
}
# x with a newline after it
xn() {
  x $1 $2
  # print a newline only if the string does not end in a newline
  [[ "$1" == "${1%$'\n'}" ]] && echo
}

assert $(x a 3) == aaa "x function should repeat a string"
assert "$(xn "a\n" 2)" == "a\na\n" "xn function should repeat a string with a newline"

# only enable this on arch somehow
# source ~/bin/pac

# GIT shortcuts
alias gb='git branch'
# alias gbnotes='git branch --edit-description'
# alias gba='git branch -a'
alias gc='EDITOR="subl" git commit -v'
alias push='git push'
# alias pushforce='git push -f'
alias pull='git pull'
alias puff='git puff' # pull --ff-only
# alias fetch='git fetch'
# alias co='git checkout' # NOTE: overwrites a builtin for RCS (wtf? really? RCS?)
# alias checkout='git checkout'
alias gco='git checkout'
# alias gpp='git pull;git push'
# alias gst='git status'
alias ga='git add -v'
alias gs='git status'
alias gcb='git checkout -b'
alias gitrollback='git reset --hard; git clean -f'
alias gunadd='git reset HEAD'
alias grc='git rebase --continue'

# git functions
#$PIPEABLE_EDITOR;
# gd() {
#   git diff ${1} | subl ;
# }

# function rbr {
#  git checkout $1;
#  git pull origin $1;
#  git checkout $2;
#  git rebase $1;
# }

# function mbr {
#  git checkout $1;
#  git merge $2
#  git push origin $1;
#  git checkout $2;
# }

# the following depend on the parse_git_branch function defined elsewhere
# function rebase_to_latest_master {
#   cur=$(parse_git_branch);
#   git stash;
#   git checkout master;
#   git pull origin master;
#   git checkout $cur;
#   git rebase master;
#   git stash pop;
# }

# 'git pull origin master' shortcut, but make sure you're on master first!
# function gpom {
#   cur=$(parse_git_branch);
#   if [ $cur = 'master' ]; then
#     git pull origin master;
#   else
#     echo "DUDE! You aren't on master branch!"
#   fi
# }

# function open_all_files_changed_from_master {
#   if [ -d .git ]; then
#     $EDITOR .
#     for file in `git diff --name-only master`
#     do
#       $EDITOR $file
#     done
#   else
#     echo "Hey man. You're not in a directory with a git repo."
#   fi
# }

# automated git bisecting. because I hate remembering how to use this.
# ex. usage: git_wtf_happened <ruby testfile> <how many commits back, default 8>
# function git_wtf_happened {
#   git bisect start HEAD HEAD~${2:-8};
#   shift;
#   git bisect run $1;
#   git bisect view;
#   git bisect reset;
# }

# lines of code counter
# brew install tokei
alias loc='tokei'

# homebrew utils
bubu () { brew update; brew upgrade; }

# Postgres wrapper stuff
pg() {
  case $1 in
  start)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl -l $PGDATA/server.log start${ANSI}${TXTDFT}"
    pg_ctl -l $PGDATA/server.log start
    ;;
  stop)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl stop -m fast${ANSI}${TXTDFT}"
    ;;
  status)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl status${ANSI}${TXTDFT}"
    ;;
  restart)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl reload${ANSI}${TXTDFT}"
    ;;
  *)
    echo "Usage: pg start|stop|status|restart"
    echo "This function is defined in $BASH_SOURCE"
    ;;
  esac
}

# git functions and extra config
source ~/bin/git-branch.bash # defines parse_git_branch and parse_git_branch_with_dirty
source ~/bin/git-completion.bash

# personal push notifications
# example usage:
# notify 'It works!'
# (Use single quotes to avoid having to escape all punctuation but single quote)

notify() {
  curl -s -F "token=$PUSHOVER_NOTIFICATION_TOKEN" \
  -F "user=$PUSHOVER_NOTIFICATION_USER" \
  -F "message=$1" https://api.pushover.net/1/messages.json
  # -F "title=YOUR_TITLE_HERE" \
}

# my version of find file
# ff [[<start path, defaults to .>] <searchterm>] (ff with no arguments lists all files recursively from $PWD)
# so fd on linux when installed via apt has the name fdfind, complicating matters
fdbin=fd
command -v $fdbin >/dev/null 2>&1 || fdbin=fdfind
command -v $fdbin >/dev/null 2>&1 || fdbin=fd
ff() {
  needs $fdbin cargo install fd-find or apt install fd-find \(binary is named fdfind then\)
  case $1 in
  -h | --help)
    echo "Find File (pmarreck wrapper function)"
    echo 'Usage: ff [<start path> <searchterm> | "<searchterm>" <start path> | <searchterm>]'
    echo '(defaults to starting in current directory if no valid directory argument is provided)'
    echo "This function is defined in ${BASH_SOURCE[0]}"
    echo '(ff with no arguments lists all files recursively from $PWD)'
    ;;
  *)
    local dir=""
    local term=""
    # I did this logic because I got tired of remembering whether the (optional) directory argument was
    # the first or second argument, lol. (Computers are smart, they can make this easier!)
    # If either of the first 2 arguments is a valid directory, use that as the directory argument
    # and use the other argument (or the rest of the arguments if the directory argument was the first argument)
    # as the search query.
    # If no valid directory argument is provided, default to the current directory
    # and use all arguments as a search term.
    [ -d "$2" ] && dir="$2" && term="$1"
    [ -d "$1" ] && dir="$1" && shift && term="$*"
    [ -z "$dir" ] && dir="$PWD" && term="$*" && echo -e "${ANSI}${TXTYLW}Searching from current directory ${PWD}...${ANSI}${TXTRST}" >&2
    # search all hidden and gitignore'd files
    # Note: Not including -jN argument (where N is a lowish number)
    # currently results in massive slowdown due to bug: https://github.com/sharkdp/fd/issues/1131
    # I made it -j2 after some testing
    >&2 echo -e "${ANSI}${TXTYLW}${fdbin} -j2 -HI \"${term}\" \"${dir}\"${ANSI}${TXTRST}"
    $fdbin -j2 -HI "$term" "$dir"
    ;;
  esac
}

# set the date bin to gdate (or one that recognizes --resolution) if available
datebin=date
$datebin --resolution >/dev/null 2>&1 || datebin=gdate
$datebin --resolution >/dev/null 2>&1 || datebin=date
# use perl for timestamps if the date timestamp resolution isn't small enough
_use_perl_for_more_accurate_timestamps=0
if [ "$($datebin --resolution)" != "0.000000001" ]; then
  _use_perl_for_more_accurate_timestamps=1
fi
# For the Ruby fans.
# Floating point seconds since epoch, to nanosecond resolution.
Time.now.to_f() {
  if [ $_use_perl_for_more_accurate_timestamps -eq 1 ]; then
    perl -MTime::HiRes=time -e 'printf "%.9f\n", time'
  else
    $datebin +'%s.%N'
  fi
}

# Nanoseconds since unix epoch.
# Might be cheap just to strip the decimal, but there's always a fixed number of digits to the right of the decimal
now_in_ns() {
  local now=$(Time.now.to_f)
  echo ${now//.}
}

# Lets you time different parts of your bash code consecutively to see where slowdowns are occurring.
# Usage example:
# note_time_diff --start
# ... one or more commands ...
# note_time_diff "some note about the previous command"
# ... more commands ...
# note_time_diff
# ... more commands ...
# note_time_diff --end
note_time_diff() {
  case $1 in
  --start)
    _start_time=$(Time.now.to_f)
    _interstitial_time=$_start_time
    echo "timestart: $_start_time"
    ;;
  --end)
    local _end_time=$(Time.now.to_f)
    local totaltimediff=$(echo "scale=10;$_end_time - $_start_time" | bc)
    local timediff=$(echo "scale=10;$_end_time - $_interstitial_time" | bc)
    echo "timediff: $timediff"
    echo "time_end: $_end_time"
    echo "totaltimediff: $totaltimediff"
    unset _start_time
    unset _interstitial_time
    ;;
  *)
    local _now=$(Time.now.to_f)
    local timediff=$(echo "scale=10;$_now - $_interstitial_time" | bc)
    echo "timediff: $timediff $1"
    _interstitial_time=$_now
    ;;
  esac
}

# inline ff test
_fftest() {
  local - # scant docs on this but this apparently automatically resets shellopts when the function exits
  set -o errexit
  local _testlocname=$(randompass 10)
  if assert "${#_testlocname}" == "10" "Generated test location name for ff test is not working: ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"; then
    local _testloc="/tmp/$_testlocname"
    # the point of [ 1 == 0 ] below is to fail the line and trigger errexit IF errexit is set
    mkdir -p $_testloc >/dev/null 2>&1 || ( echo "Cannot create test directory '$_testloc' in ff test: ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"; [ 1 == 0 ] )
    touch $_testloc/$_testlocname
    pushd $_testloc >/dev/null
    assert $(ff $_testlocname 2>/dev/null) == "$_testloc/$_testlocname"
    assert $(ff 2>/dev/null) == "$_testloc/$_testlocname"
    popd >/dev/null
    pushd $HOME >/dev/null
    assert $(ff $_testloc $_testlocname 2>/dev/null) == "$_testloc/$_testlocname"
    assert $(ff $_testlocname $_testloc 2>/dev/null) == "$_testloc/$_testlocname"
    popd >/dev/null
    rm $_testloc/$_testlocname
    rm -d $_testloc
  fi
}
_fftest # why the frick is this taking a half second to run??
# ...EDIT: Turns out to be an fd bug, I put in a workaround: https://github.com/sharkdp/fd/issues/1131
assert $- !=~ e "errexit shellopt is still set after function exit: ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"
unset _fftest
# end inline ff test

# command prompt
$INTERACTIVE_SHELL && source ~/.commandpromptconfig

ltrim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  printf '%s' "$var"
}

rtrim() {
  local var="$*"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

trim() {
  local var="$*"
  var="$(ltrim "$var")"
  var="$(rtrim "$var")"
  printf '%s' "$var"
}

assert "$(ltrim "  foo  ")" == "foo  "
assert "$(rtrim "  foo  ")" == "  foo"
assert "$(trim "  foo  ")" == "foo"

# "simulate" decimal division with integers and a given number of significant digits of the mantissa
# without using bc or awk because I hate firing up a new process for something so simple
div() {
  local sd=${3:-2}
  case $1 in
  -h | --help | "")
    echo "Divide two numbers as decimal, not integer"
    echo "Usage: div <numerator> <denominator> [<digits after decimal point, defaults to 2>]"
    echo "This function is defined in $BASH_SOURCE"
    echo "Note that the result is truncated to $sd significant digits after the decimal point,"
    echo "NOT rounded from the next decimal place."
    echo "Also, things get weird with big arguments; compare 'div 1234234 121233333 5' with 'div 1234234 121233333 50'."
    echo "Not sure why, yet; possibly internal bash integer overflow."
    ;;
  *)
    printf "%.${sd}f\n" "$((10**${sd} * ${1}/${2}))e-${sd}"
    ;;
  esac
}

assert "$(div 22 15)" == "1.46"
assert "$(div 1234234 121233333 5)" == "0.01018"

flip_a_coin() {
  (( RANDOM % 2 )) && echo "heads" || echo "tails"
}

# testing this is interesting...
assert $(RANDOM=0 flip_a_coin) == "tails"
assert $(RANDOM=1 flip_a_coin) == "heads"

roll_a_die() {
  # so the trick to be strictly correct here is that 32767 is not evenly divisible by 6,
  # so there will be bias UNLESS you cap at 32766
  # since 32766 is evenly divisible by 6 (5461)
  local candidate=$RANDOM
  while [ $candidate -gt 32766 ]; do
    candidate=$RANDOM
  done
  echo $((1 + $candidate % 6))
}

assert $(RANDOM=5 roll_a_die) == "6"
assert $(RANDOM=6 roll_a_die) == "1"

# usage: repeat <number of times> <command>
repeat() {
  local count=$1
  shift
  cmd=($@)
  for ((i = 0; i < count; i++)); do
    eval "${cmd[@]}"
  done
}

assert "$(repeat 3 "echo -n \"hi \"")" == 'hi hi hi '

# silliness
if $INTERACTIVE_SHELL; then
  echo
  if [ "$(flip_a_coin)" = "heads" ]; then
    needs fortune
    fortune
    echo
  else
    # in the beginning... was the command line
    needs convert please install imagemagick
    convert $HOME/inthebeginning.jpg -geometry 800x480 sixel:-
  fi
fi

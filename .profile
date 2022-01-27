$DEBUG_SHELLCONFIG && [[ $- == *i* ]] && echo "Running .profile" || echo "#" # last debug gets a crlf

[[ $- == *i* ]] && echo "Platform: $PLATFORM"

# config for Visual Studio Code
if [ "$PLATFORM" = "osx" ]; then
  code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode --args $* ;}
  pipeable_code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode -f ;}
  export PIPEABLE_EDITOR='pipeable_code'
fi
# export EDITOR='code' # already set in .bashrc

# If you hate noise
# set bell-style visible

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
alias line='sed -n '\''\!:1 p'\'' \!:2'    # line 5 file => show line 5 of file
# alias l='ls -lGaph'
# brew install exa
needs exa
alias l='exa --long --header --sort=mod --all'
alias l1='l --git --icons'
alias l2='l1 --tree --level=2'
alias l3='l1 --tree --level=3' #--extended 
alias l4='l1 --tree --level=4'
# alias ll='ls -lagG \!* | more'
# alias term='set noglob; unset TERMCAP; eval `tset -s -I -Q - \!*`'
# alias rehash='hash -r'
alias rehash='source "$HOME/.bash_profile"'
# alias rehash='source ~/.profile'
# alias word='grep \!* /usr/share/dict/web2' # Grep thru dictionary
alias tophog='top -ocpu -s 3'
#alias wordcount=(cat \!* | tr -s '\''  .,;:?\!()[]"'\'' '\''\012'\'' |' \
#                'cat -n | tail -1 | awk '\''{print $1}'\'')' # Histogram words
# alias js='java org.mozilla.javascript.tools.shell.Main'
scr() {
  needs screen
  screen -r
}
alias p='ping www.yahoo.com'
alias pp='ping -A -i 5 8.8.4.4' #Ping the root google nameserver every 5 seconds and beep if no route
alias t='top'
# alias tu='top -ocpu -Otime'
alias bye='logout'

# The current thing(s) I'm working on
alias mpnetwork='cd ~/Documents/mpnetwork*'
alias simpaticio='cd ~/Documents/simpaticio'
alias work=mpnetwork

# alias ss='script/server'
# alias sc='script/console'
# alias rc='rails console'

# network crap
alias killdns='sudo killall -HUP mDNSResponder'

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

# forkbomb!
# alias forkbomb=':(){ :|:& };:'

# sublime command to open stuff in OS X
# if [ "$PLATFORM" == "osx" ]; then
#   sublime() { open -a "Sublime Text 2.app" "${1:-.}"; }
# fi

# alias b='bundle | grep -v "Using"'
# alias be='bundle exec'
# alias zs='rm .zeus.sock; zeus start'
# alias z='zeus'

# test reporter config
# export REPORTER=progress,failtest,slowtest,sound

# function rubytest() {
#   RAILS_ENV=test time bundle exec ruby -Ilib:test:. -e "ARGV.each{|f| require f}" $@
# }
# function deskonetest() {
#   export REPORTER=${REPORTER/,?spec/},spec
#   RAILS_ENV=test time rake assistly:test:${2:-units} TEST=${1} ${3}
# }
# function unit() {
#   export REPORTER=${REPORTER/,?spec/},spec
#   count=1
#   xitstatus=-1
#   test_failures=0
#   if [ $# -ne 1 ]
#   then
#     echo "Running $# tests..."
#   fi
#   for tst #in "$@" # the latter is actually assumed! awesome.
#   do
#     echo "Running test ($count/$#) $tst ..."
#     RAILS_ENV=test time bundle exec ruby -Ilib:test $tst && xitstatus=$?
#     if [ $xitstatus -ne 0 ]; then
#       test_failures=$[test_failures+1]
#     fi
#     count=$[count+1]
#   done
#   if [ $test_failures -ne 0 ]; then
#     if [ $# -ne 1 ]
#     then
#       echo -e "There were ${ANSI}${BLDRED}$test_failures TEST FAILS!!${ANSI}${TXTRST}"
#     else
#       echo -e "There was ${ANSI}${BLDRED}$test_failures TEST FAIL!!${ANSI}${TXTRST}"
#     fi
#     return -1
#   else
#     echo -e "${ANSI}${TXTGRN}ALL GREEN! SHIP IT!${ANSI}${TXTRST}"
#     return 0
#   fi
# }
# function unitnow() {
#   xitstatus=-1
#   test_failures=0
#   ruby_args='-Ilib:test'
#   for tst #in "$@" # the latter is actually assumed! awesome.
#   do
#     ruby_args="$ruby_args -r $tst"
#   done
#   RAILS_ENV=test time bundle exec ruby $ruby_args && xitstatus=$?
# }

# function desktest() {
#   xitstatus=-1;
#   RAILS_ENV=test time rake assistly:test:all && xitstatus=$?
#   if [ $xitstatus -ne 0 ]; then
#     osascript -e 'tell application "Terminal" to display alert "Test Failed" buttons "Shucks."'
#   else
#     osascript -e 'tell application "Terminal" to display alert "Test Passed" buttons "Right on!"'
#   fi
#   return $xitstatus
# }

# Encryption functions. Requires the GNUpg "gpg" commandline tool. On OS X, "brew install gnupg"
# Explanation of options here:
# --symmetric - Don't public-key encrypt, just symmetrically encrypt in-place with a passphrase.
# -z 9 - Compression level
# --require-secmem - Require use of secured memory for operations. Bails otherwise.
# cipher-algo, s2k-cipher-algo - The algorithm used for the secret key
# digest-algo - The algorithm used to mangle the secret key
# s2k-mode 3 - Enables multiple rounds of mangling to thwart brute-force attacks
# s2k-count 65000000 - Mangles the passphrase this number of times. Takes over a second on modern hardware.
# compress-algo BZIP2- Uses a high quality compression algorithm before encryption. BZIP2 is good but not compatible with PGP proper, FYI.
encrypt() {
  needs gpg
  gpg --symmetric -z 9 --require-secmem --cipher-algo AES256 --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000 --compress-algo BZIP2 $@
}
# note: will decrypt to STDOUT by default, for security reasons. remove "-d" or pipe to file to write to disk
decrypt() {
  needs gpg
  gpg -d $@
}

# get a random-character password
# First argument is password length
# Can override the default character set by passing in PWCHARSET=<charset> as env
randompass() {
  needs shuf
  # globbing & history expansion here is a pain, so we store its state, temp turn it off & restore it later
  local maybeglob="$(shopt -po noglob histexpand)"
  set -o noglob # turn off globbing
  set +o histexpand # turn off history expansion
  if [ $# -eq 0 ]; then
    echo "Usage: randompass <length>"
    return 1
  fi
  # allow overriding the password character set with env var PWCHARSET
  # NOTE that we DELETE THE CAPITAL O, CAPITAL I AND LOWERCASE L CHARACTERS
  # DUE TO SIMILARITY TO 1 AND 0
  # (but only if you use the default alnum set)
  # BECAUSE WHO THE FUCK EVER THOUGHT THAT WOULD BE A GOOD IDEA? 😂
  if [ -z "$PWCHARSET" ]; then
    local lower=$(echo -n {a..z} | tr -d ' ')
    local upper=$(echo -n {A..Z} | tr -d ' ')
    local num=$(echo -n {0..9} | tr -d ' ')
    local alcharacterset="$lower$upper"
    local alnumcharacterset=$(printf "%s" "$alcharacterset$num" | tr -d 'OlI')
    local punc='!@#$%^&*-_=+[]{}|;:,.<>/?~'
    local PWCHARSET="$alnumcharacterset$punc"
  fi
  # ...but also intersperse it with spaces so that the -e option to shuf works.
  # Using awk to split the character set into a space-separated string of characters.
  # Saw some noise that empty field separator will cause awk problems,
  # but it's concise and fast and works, so... &shrug;
  # printf is necessary due to some of the punctuation characters being interpreted when using echo
  local characterset=$(printf "%s" "$PWCHARSET" | awk NF=NF FS="")
  # using /dev/random to enforce entropy, but use urandom if you want speed
  { shuf --random-source=/dev/random -n $1 -er $characterset; } | tr -d '\n'
  echo
  # restore any globbing state
  eval "$maybeglob"
  # cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9\!\@\#\$\%\&\*\?' | fold -w $1 | head -n 1
}

# get a random-dictionary-word password
# First argument is minimum word length
# Second argument is number of words to generate
randompassdict() {
  needs shuf
  if [ $# -eq 0 ]; then
    echo "Usage: randompassdict <num-words> [<min-word-length default 8> [<max-word-length default 99>]]"
    if [ "$PLATFORM" = "linux" ]; then
      echo "Note that on linux, this may require installation of the 'words' package."
    fi
    return 1
  fi
  local dict_loc="/usr/share/dict/words"
  # [ -f "$dict_loc" ] || { echo "$dict_loc missing. may need to install 'words' package. Exiting."; exit 1; }
  local numwords=$1
  local minlen=${2:-8}
  local maxlen=${3:-99}
  # take the dict, filter out anything not within the min/max length or that has apostrophes, and shuffle
  local pool=$(cat /usr/share/dict/words | awk 'length($0) >= '$minlen' && length($0) <= '$maxlen' && $0 ~ /^[^'\'']+$/')
  local poolsize=$(printf "%s" "$pool" | wc -l)
  # why is poolsize getting spaces in front? No idea. Removing them.
  poolsize=${poolsize##* }
  local words=$(echo -n "$pool" | shuf --random-source=/dev/random -n "$numwords" | tr '\n' ' ')
  echo "$words"
  echo "(out of a possible $poolsize available words in the dictionary that suit the requested length range [$minlen-$maxlen])" 1>&2
  # a former attempt that worked but was less flexible:
  #cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9\!\@\#\$\%\&\*\?' | fold -w $1 | head -n $2 | tr '\n' ' '
}


# GPG configuration to set up in-terminal challenge-response
export GPG_TTY=`tty`

# which hack, so it also shows defined aliases and functions that match
where() {
  type_out=`type "$@"`;
  if [ ! -z "$type_out" ]; then
    echo "$type_out";
  else
    /usr/bin/env which $@;
  fi
}

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

# gem opener
open_gem() {
  $EDITOR `bundle show $1`
}

# thar be dragons
dragon() {
  echo '                    ___====-_  _-====___'
  echo '              _--~~~#####//      \\#####~~~--_'
  echo '           _-~##########// (    ) \\##########~-_'
  echo '          -############//  :\^^/:  \\############-'
  echo '        _~############//   (@::@)   \\############~_'
  echo '       ~#############((     \\//     ))#############~'
  echo '      -###############\\    (^^)    //###############-'
  echo '     -#################\\  / "" \  //#################-'
  echo '    -###################\\/      \//###################-'
  echo '   _#/:##########/\######(   /\   )######/\##########:\#_'
  echo '   :/ :#/\#/\#/\/  \#/\##\  :  :  /##/\#/  \/\#/\#/\#: \:'
  echo '   "  :/  V  V  "   V  \#\: :  : :/#/  V   "  V  V  \:  "'
  echo '      "   "  "      "   \ : :  : : /   "      "  "   "'
  echo ''
}

# get current weather, output as big ASCII art
weather() {
  needs curl
  needs jq
  needs bc
  needs figlet
  temp=`curl -s "http://api.openweathermap.org/data/2.5/weather?id=$OPENWEATHERMAP_ID&APPID=$OPENWEATHERMAP_APPID" | jq .main.temp`
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

# am I the only one who constantly forgets the correct order of arguments to `ln`?
lnwtf() {
  echo 'ln -s path_of_thing_to_link_to [name_of_link]'
  echo '(If you omit the latter, it puts a same-named link in the current directory)'
}

# add otp --version command
otp() {
  needs erl
  case $1 in
    "--version")
      erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell
      ;;
    *)
      echo "Usage: otp [--version]"
      ;;
  esac
}

# add hex command to dump hex from stdin or args (note that hexdump also exists)
hex() {
  if [ -z "$1" ]; then # if no arguments
    # The following exits code 0 if stdin not empty; 1 if empty; does not consume any bytes.
    # This may only be a Bash-ism, FYI. Not sure if it's shell-portable.
    read -t 0
    retval=${?##1} # replace 1 with blank so it falses correctly if stdin is empty
    if [ "$retval" ]; then
      xxd -pu  # receive piped input from stdin
    else # if stdin is empty AND no arguments
      echo "Usage: hex <string>"
      echo "       (or pipe something to hex)"
    fi
  else # if arguments
    echo -ne "$@" | xxd -pu # pipe all arguments to xxd
  fi
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

# Who is holding open this damn port or file?? (note: may only work on OS X)
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

source ~/bin/pac

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
#   git bisect start HEAD HEAD~${1:-8};
#   shift;
#   git bisect run $*;
#   git bisect view;
#   git bisect reset;
# }

# lines of code counter
# brew install tokei
needs tokei
alias loc='tokei'

# homebrew utils
bubu () { brew update; brew upgrade; }

# Postgres stuff
alias start-pg='pg_ctl -l $PGDATA/server.log start'
alias stop-pg='pg_ctl stop -m fast'
alias show-pg-status='pg_ctl status'
alias restart-pg='pg_ctl reload'

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

# command prompt
# using oh-my-bash for now
# [[ $- == *i* ]] && source ~/.commandpromptconfig

# silliness
if [[ $- == *i* ]]; then
  needs fortune
  echo
  fortune
  echo
fi

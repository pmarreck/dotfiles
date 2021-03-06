[[ $- == *i* ]] && echo "Running .profile"

source ~/.envconfig

[[ $- == *i* ]] && echo "Platform: $PLATFORM"

# config for Visual Studio Code
code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode --args $* ;}
pipeable_code () { VSCODE_CWD="$PWD" open -n -b com.microsoft.VSCode -f ;}
export EDITOR='code'
export PIPEABLE_EDITOR='pipeable_code'

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
alias .='pwd'
alias ..='cd ..'
alias cd..='cd ..'
alias cdwd='cd `pwd`'
alias cwd='echo $cwd'
alias files='find \!:1 -type f -print'      # files x => list files in x
alias ff='find . -name \!:1 -print'      # ff x => find file named x
alias line='sed -n '\''\!:1 p'\'' \!:2'    # line 5 file => show line 5 of file
alias l='ls -lGaph'
alias ll='ls -lagG \!* | more'
# alias term='set noglob; unset TERMCAP; eval `tset -s -I -Q - \!*`'
# alias rehash='hash -r'
alias rehash='source "$HOME/.bash_profile"'
# alias rehash='source ~/.profile'
# alias word='grep \!* /usr/share/dict/web2' # Grep thru dictionary
alias tophog='top -ocpu -s 3'
#alias wordcount=(cat \!* | tr -s '\''  .,;:?\!()[]"'\'' '\''\012'\'' |' \
#                'cat -n | tail -1 | awk '\''{print $1}'\'')' # Histogram words
# alias js='java org.mozilla.javascript.tools.shell.Main'
alias scr='screen -r'
alias p='ping www.yahoo.com'
alias pp='ping -A -i 5 8.8.4.4' #Ping the root google nameserver every 5 seconds and beep if no route
alias t='top'
# alias tu='top -ocpu -Otime'
alias bye='logout'

# The current thing(s) I'm working on
alias mpnetwork='cd ~/Documents/mpnetwork'
alias simpaticio='cd ~/Documents/simpaticio'
alias work=simpaticio

alias ss='script/server'
alias sc='script/console'
alias rc='rails console'

# network crap
alias killdns='sudo killall -HUP mDNSResponder'

# why is grep dumb?
# alias grep='egrep'

# elixir/phoenix gigalixir prod deploy command
alias deploy='git push gigalixir master'

# log all terminal output to a file
alias log='/usr/bin/script -a ~/Terminal.log; source ~/.bash_profile'

# This was inevitable.
alias btc='curl -s https://www.bitstamp.net/api/ticker/ | jq ".last | tonumber" | figlet -kcf big'

# from https://twitter.com/liamosaur/status/506975850596536320
# this just runs the previously-entered command as sudo
alias fuck='sudo $(history -p \!\!)'

### Different ways to print a "beep" sound. I settled on the last one. It's shell-agnostic.
# From http://stackoverflow.com/questions/3127977/how-to-make-the-hardware-beep-sound-in-mac-os-x-10-6
# alias beep='echo -en "\007"'
# alias beep='printf "\a"'
alias beep='tput bel'

# sublime command to open stuff in OS X
if [ "$PLATFORM" == "osx" ]; then
  sublime() { open -a "Sublime Text 2.app" "${1:-.}"; }
fi

alias b='bundle | grep -v "Using"'
alias be='bundle exec'
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
  gpg --symmetric -z 9 --require-secmem --cipher-algo AES256 --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000 --compress-algo BZIP2 $@
}
# note: will decrypt to STDOUT by default, for security reasons. remove "-d" or pipe to file to write to disk
decrypt() {
  gpg -d $@
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

# weather
weather() {
  temp=`curl -s "http://api.openweathermap.org/data/2.5/weather?id=5132029&APPID=516c2c718e4cb6c921bf1eea495df7e9" | jq .main.temp`
  temp=$(bc <<< "$temp*9/5-459.67") # convert from kelvin to F
  echo "$temp F" | figlet -kcf big
}
# ansiweather's is 85a4e3c55b73909f42c6a23ec35b7147
# mine is 516c2c718e4cb6c921bf1eea495df7e9 but it did not work after I created it... time delay?
# EDIT: Works now
# But returns Kelvin. Don't have time to figure out F from K in Bash using formula F = K * 9/5 - 459.67
# EDIT 2: Figured that out

# am I the only one who constantly forgets the correct order of arguments to `ln`?
lnwtf() {
  echo 'ln -s path_of_thing_to_link_to [name_of_link]'
  echo '(If you omit the latter, it puts a same-named link in the current directory)'
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

# Sexy man pages. Opens a postscript version in Preview.app on OS X
if [ "$PLATFORM" == "osx" ]; then
  pman() { man -t "$@" | open -f -a Preview; }
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

# GIT shortcuts
alias gb='git branch'
# alias gbnotes='git branch --edit-description'
# alias gba='git branch -a'
alias gc='EDITOR="subl" git commit -v'
alias push='git push'
# alias pushforce='git push -f'
alias pull='git pull'
alias puff='git puff' # pull --ff-only
alias fetch='git fetch'
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
gd() {
  git diff ${1} | subl;
}

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
alias loc='tokei'

# homebrew utils
bubu () { brew update; brew upgrade ;}

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
  curl -s -F "token=awg3fvs3vjnamuqof99r2246j8q3eh" \
  -F "user=uxrxropwvwyx72dheuhmgf8fti96me" \
  -F "message=$1" https://api.pushover.net/1/messages.json
  # -F "title=YOUR_TITLE_HERE" \
}

# command prompt
[[ $- == *i* ]] && source ~/.commandpromptconfig

# silliness
if [[ $- == *i* ]]; then
  echo
  fortune
fi

[[ $- == *i* ]] && echo "Running .profile"

if [ "$(uname)" == "Darwin" ]; then
  export PLATFORM='osx'      
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  export PLATFORM='linux'
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
  export PLATFORM='windows'
fi
[[ $- == *i* ]] && echo "Platform: $PLATFORM"

# Experimental "Plan 9 from User Space" PATH config
# export PLAN9=/usr/local/plan9
# export PATH=$PATH:$PLAN9/bin

# stop checking for unix mail, OS X!
unset MAILCHECK

# make sure this points to the correct gcc!
# export CC=gcc-4.7
# export CFLAGS="-march=native"
# the following is per "brew install libtool" instructions
# export LDFLAGS=-L/usr/local/opt/libtool/lib
# export CPPFLAGS=-I/usr/local/opt/libtool/include
# per https://trac.macports.org/ticket/27237
# export CXXFLAGS="-U_GLIBCXX_DEBUG -U_GLIBCXX_DEBUG_PEDANTIC"

# Node.js
export NODE_PATH=/usr/local/lib/node

# Color constants
export ANSI="\033["
export TXTBLK='0;30m' # Black - Regular
export TXTRED='0;31m' # Red
export TXTGRN='0;32m' # Green
export TXTYLW='0;33m' # Yellow
export TXTBLU='0;34m' # Blue
export TXTPUR='0;35m' # Purple
export TXTCYN='0;36m' # Cyan
export TXTWHT='0;37m' # White
export BLDBLK='1;30m' # Black - Bold
export BLDRED='1;31m' # Red
export BLDGRN='1;32m' # Green
export BLDYLW='1;33m' # Yellow
export BLDBLU='1;34m' # Blue
export BLDPUR='1;35m' # Purple
export BLDCYN='1;36m' # Cyan
export BLDWHT='1;37m' # White
export UNDBLK='4;30m' # Black - Underline
export UNDRED='4;31m' # Red
export UNDGRN='4;32m' # Green
export UNDYLW='4;33m' # Yellow
export UNDBLU='4;34m' # Blue
export UNDPUR='4;35m' # Purple
export UNDCYN='4;36m' # Cyan
export UNDWHT='4;37m' # White
export BAKBLK='40m'   # Black - Background
export BAKRED='41m'   # Red
export BAKGRN='42m'   # Green
export BAKYLW='43m'   # Yellow
export BAKBLU='44m'   # Blue
export BAKPUR='45m'   # Purple
export BAKCYN='46m'   # Cyan
export BAKWHT='47m'   # White
export TXTRST='0m'    # Text Reset, disable coloring

# Add the following to your ~/.bashrc or ~/.zshrc
#
# Alternatively, copy/symlink this file and source in your shell.  See `hitch --setup-path`.

hitch() {
  command hitch "$@"
  if [[ -s "$HOME/.hitch_export_authors" ]] ; then source "$HOME/.hitch_export_authors" ; fi
}
alias unhitch='hitch -u'

# Uncomment to persist pair info between terminal instances
# hitch

source ~/.pathconfig

# Default editor
# export EDITOR=mate
export EDITOR='subl'
# Specifying -w will cause the subl command to not exit until the file is closed
# export EDITOR=${EDITOR/\-w/}

# change the title of the terminal window (only in OS X?)
# See http://hints.macworld.com/article.php?story=20031015173932306
# Note that this has to run before the command history PROMPT_COMMAND tweak below
# export PROMPT_COMMAND='echo -ne "\033]0;$@\007"'

### Command history tweaks
# shopt -s histappend
# shopt -s cmdhist
# export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
# export HISTSIZE=100000                   # big big history
# export HISTFILESIZE=100000               # big big history
# export HISTIGNORE="&:[bf]g:exit"
# Shared command history among all terminal windows
# Please see http://ptspts.blogspot.com/2011/03/how-to-automatically-synchronize-shell.html
# Damn it. Only works with bash > v4.0
# source "$HOME"/bin/merge_history.bash
# Fall back to an alternate method. The problem with this method is that it
# only propagates the command after it finishes.
# Save and reload the history after each command finishes
# export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# color TERM support... possibly no longer necessary
# export TERM=dtterm
# export TERM=xterm-color

# If you hate noise
# set bell-style visible

# Pager config (ex., for git diff output)
#E=quit at first EOF
#Q=no bell
#R=pass through raw ansi so colors work
#X=no termcap init
export LESS="-EQRX"

# ulimit. I still don't know entirely what the fuck a ulimit is, but this helps things.
# (and yes, I tried "man ulimit", go ahead and try it yourself)
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
alias rehash='hash -r'
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

# The current thing I'm working on
alias work='cd ~/Documents/fortythreebytes-ui'

alias ss='script/server'
alias sc='script/console'
alias rc='rails console'

alias fortythreestaging='ssh -i ~/.ssh/staging_rsa sparkadmin@staging.43bytes.com'
alias fortythreeproduction='ssh -i ~/.ssh/prod_rsa sparkadmin@43bytes.com'

# network crap
alias killdns='sudo killall -HUP mDNSResponder'

# why is grep dumb?
# alias grep='egrep'

# log all terminal output to a file
alias log='/usr/bin/script -a ~/Terminal.log; source ~/.bash_profile'

# This was inevitable.
alias btc='curl -s https://www.bitstamp.net/api/ticker/ | jq ".last | tonumber"'

# free amazon EC2 usage tier box
EC2USER='ec2-user'
EC2BOX='ec2-184-72-178-19.compute-1.amazonaws.com'
SSHEC2IDFILE='~/.ssh/pmamazonkey.pem'
alias ec2box="ssh -i $SSHEC2IDFILE $EC2USER@$EC2BOX"
ec2_dropbox_push() {
  scp -i $SSHEC2IDFILE "$1" $EC2USER@$EC2BOX:${2:-\~/Dropbox/}
}
ec2_dropbox_pull() {
  scp -i $SSHEC2IDFILE $EC2USER@$EC2BOX:${1:-\~/Dropbox/\*} "${2:-.}"
}

### Different ways to print a "beep" sound. I settled on the last one. It's shell-agnostic.
# From http://stackoverflow.com/questions/3127977/how-to-make-the-hardware-beep-sound-in-mac-os-x-10-6
# alias beep='echo -en "\007"'
# alias beep='printf "\a"'
alias beep='tput bel'

# sublime command to open stuff in OS X
if [ "$PLATFORM" == "osx" ]; then
  sublime() { open -a "Sublime Text 2.app" "${1:-.}"; }
fi

# thredup specific
# alias tu='cd ~/Sites/Rails/thredUP/'
# alias tu2='cd ~/Sites/Rails/thredUP2/'
# alias tu3='cd ~/Sites/Rails/thredUP3/'
# alias convo='cd ~/Sites/Rails/convozine/'
# alias go_pro='ssh -p 35987 thredup@thredup.com'
# alias go_util='ssh -p 35987 thredup@utility.thredup.com'
# alias go_ec2='ssh -p 35987 thredup@ec2.thredup.com'
# alias get_new_prod_db='scp -P 35987 thredup@thredup.com:/tmp/thredup.sql.gz ~/Desktop/'
# alias pass='rvmsudo passenger start -p 80 -a peter.local --user=pmarreck'
# alias rst='touch tmp/restart.txt'

# Ruby environment tweaking
export RUBY_GC_HEAP_INIT_SLOTS=1000000
export RUBY_HEAP_SLOTS_INCREMENT=1000000
export RUBY_HEAP_SLOTS_GROWTH_FACTOR=1
export RUBY_GC_MALLOC_LIMIT=100000000
export RUBY_HEAP_FREE_MIN=500000
export RUBY_GC_HEAP_FREE_SLOTS=200000

####### assistly/desk specific ########
# export ASSISTLY_LOG_LEVEL=debug
# export ASSISTLY_DEBUG=true
# export DEBUG=true
# export REPORTER=spec
# alias deskjobs='work; script/jobs start; tail -f log/development-backend.log'
# alias deskstart='work; foreman start'
# alias deskkill='killall ruby; killall nginx'
# alias deskcleares='work; rake assistly:es:index:remove_all; rake assistly:es:index:build; rake assistly:es:index:prune_versions'
# alias deskguard='work; guard'
# alias estest='bundle exec rake desk:es:start[test]'
# alias esdev='bundle exec rake desk:es:start'
# alias esdevz='zeus rake desk:es:start'
alias b='bundle | grep -v "Using"'
alias be='bundle exec'
# alias zs='rm .zeus.sock; zeus start'
# alias z='zeus'
# alias dfr='desk-flow ticket review'

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

# function desktestsetup() {
#   RAILS_ENV=test rake ci:setup:db;
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

# function set_database() {
#   export SPECIFIC_DB="$1"
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
  $EDITOR $@
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

# function resetData {
#   cd ~/Sites/Rails/thredUP3/
#   mysql -u root --execute="DROP DATABASE ${1:-thredup3_development};"
#   mysql -u root --execute="CREATE DATABASE ${1:-thredup3_development};"
#   gunzip -c ${2:-./db/thredup.sql.gz} > ${3:-./tmp/thredup.sql}
#   mysql -u root ${1:-thredup3_development} < ${3:-./tmp/thredup.sql}
#   mysql -u root ${1:-thredup3_development} < ${4:-./db/clean_test_data.sql}
#   rm ${3:-./tmp/thredup.sql}
#   rake db:migrate
# }
# Usage:   resetData [thredup3_development ./db/thredup.sql.gz ./tmp/thredup.sql]

# function mysql_clone_develop_db {
#   cur=${1:-$(parse_git_branch)}
#   db_name=${cur//[\.\/\-]/_}
#   db_name=${db_name//tickets_AA/aa}
#   testsuffix='_test'
#   test_db_name=$db_name$testsuffix
#   if [[ $db_name =~ _test[0-9]{0,2}$ ]] ; then # if you specifically name a test db, only do it
#     echo Dropping database $db_name
#     mysql -u root --execute="DROP DATABASE \`${db_name}\`;"
#     echo Recreating database $db_name
#     mysql -u root --execute="CREATE DATABASE \`${db_name}\`;"
#   else
#     echo Dropping databases $db_name and $test_db_name
#     mysql -u root --execute="DROP DATABASE \`${db_name}\`; DROP DATABASE \`${test_db_name}\`;"
#     echo Recreating databases $db_name and $test_db_name
#     mysql -u root --execute="CREATE DATABASE \`${db_name}\`; CREATE DATABASE \`${test_db_name}\`;"
#   fi
#   if [[ $db_name =~ _test[0-9]{0,2}$ ]] ; then
#     echo Cloning develop_test to $db_name
#     mysqldump -u root develop_test | pv - -p -r | mysql -u root -h localhost $db_name
#   else
#     echo Cloning develop to $db_name
#     mysqldump -u root develop | pv - -p -r | mysql -u root -h localhost $db_name
#     echo Cloning develop_test to $test_db_name
#     mysqldump -u root develop | pv - -p -r | mysql -u root -h localhost $test_db_name
#   fi
# }

# function mysql_clone_db {
#   from=${1}
#   db_name=${2}
#   echo Dropping database $db_name
#   mysql -u root --execute="DROP DATABASE \`${db_name}\`;"
#   echo Recreating database $db_name
#   mysql -u root --execute="CREATE DATABASE \`${db_name}\`;"
#   echo Cloning $from to $db_name
#   mysqldump -u root $from | pv - -p -r | mysql -u root -h localhost $db_name
# }

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

# Passenger shortcuts
# alias passenger-restart='work; touch tmp/restart.txt'

# GIT shortcuts
alias gb='git branch'
# alias gbnotes='git branch --edit-description'
# alias gba='git branch -a'
alias gc='git commit -v'
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
gd() {
  git diff ${1} | $EDITOR;
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

# git functions and extra config
source ~/bin/git-branch.bash # defines parse_git_branch and parse_git_branch_with_dirty
source ~/bin/git-completion.bash

# command prompt
[[ $- == *i* ]] && source ~/.commandpromptconfig

#supercolor
# PS1="\[$(tput rev)\]$PS1\[$(tput sgr0)\]"
# PS1="\[$(tput setaf 1)\]$PS1\[$(tput sgr0)\]"

# IRC hackery
# export IRCNICK="lectrick"
# export IRCUSER="Any"
# export IRCNAME="Peter"
# export IRCSERVER="irc.freenode.net"

# RVM integration

# silliness
if [[ $- == *i* ]]; then
  echo
  fortune
fi

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

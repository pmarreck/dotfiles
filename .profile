echo "Running .profile"
source ~/.bashrc
# add my user bin to PATH
# export PATH=$PATH:~/bin
export PATH=${PATH/~\/bin:/}:~/bin

# add my Scripts bin to PATH
# export PATH=$PATH:~/Scripts
export PATH=${PATH/~\/Scripts:/}:~/Scripts

# BINSTUBS
# add binstub to front of PATH
export PATH=./bin:${PATH/\.\/bin:/}

# Default editor
# export EDITOR=mate
export EDITOR='subl'
# Specifying -w will cause the subl command to not exit until the file is closed
# export EDITOR=${EDITOR/\-w/}

# change the title of the terminal window
# See http://hints.macworld.com/article.php?story=20031015173932306
# Note that this has to run before the command history PROMPT_COMMAND tweak below
export PROMPT_COMMAND='echo -ne "\033]0;$@\007"'

### Command history tweaks
shopt -s histappend
# shopt -s cmdhist
export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
export HISTIGNORE="&:[bf]g:exit"
# Shared command history among all terminal windows
# Please see http://ptspts.blogspot.com/2011/03/how-to-automatically-synchronize-shell.html
# Damn it. Only works with bash > v4.0
# source "$HOME"/bin/merge_history.bash
# Fall back to an alternate method. The problem with this method is that it
# only propagates the command after it finishes.
# Save and reload the history after each command finishes
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

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

####### Aliases
#what most people want from od (hexdump)
alias hd='od -Ax -tx1z -v'
#just list directories
alias lld='ls -lUd */'
alias .='pwd'
alias ..='cd ..'
alias cd..='cd ..'
alias cdwd='cd `pwd`'
alias cwd='echo $cwd'
# alias files='find \!:1 -type f -print'      # files x => list files in x
# alias ff='find . -name \!:1 -print'      # ff x => find file named x
alias line='sed -n '\''\!:1 p'\'' \!:2'    # line 5 file => show line 5 of file
alias l='ls -lGaph'
alias ll='ls -lagG \!* | more'
# alias term='set noglob; unset TERMCAP; eval `tset -s -I -Q - \!*`'
# alias rehash='hash -r'
alias rehash='source ~/.profile'
alias word='grep \!* /usr/share/dict/web2' # Grep thru dictionary
#alias tophog='top -ocpu -s 3'
#alias wordcount=(cat \!* | tr -s '\''  .,;:?\!()[]"'\'' '\''\012'\'' |' \
#                'cat -n | tail -1 | awk '\''{print $1}'\'')' # Histogram words
alias js='java org.mozilla.javascript.tools.shell.Main'
alias scr='screen -r'
alias p='ping www.yahoo.com'
alias pp='ping -A -i 5 8.8.4.4' #Ping the root google nameserver every 5 seconds and beep if no route
alias t='top'
# alias tu='top -ocpu -Otime'
alias bye='logout'

# The current thing I'm working on
alias work="cd $DESK_ROOT"
# The directory running a test on a branch
alias tst="cd $TEST_ROOT"

alias ss='script/server'
alias sc='script/console'
alias rc='rails console'
alias pps='passenger start'
alias dbm='rake db:migrate; rake db:test:prepare'

# network crap
alias killdns='sudo killall -HUP mDNSResponder'

# why is grep dumb?
alias grep='egrep'

# free amazon EC2 usage tier box
EC2USER='ec2-user'
EC2BOX='ec2-184-72-178-19.compute-1.amazonaws.com'
SSHEC2IDFILE="/Users/pmarreck/.ssh/pmamazonkey.pem"
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

# sublime command to open stuff
sublime() { open -a "Sublime Text 2.app" "${1:-.}"; }

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
alias rst='touch tmp/restart.txt'

####### assistly/desk specific ########
# export ASSISTLY_LOG_LEVEL=debug
# export ASSISTLY_DEBUG=true
# export DEBUG=true
# export REPORTER=spec
alias deskjobs='work; script/jobs start; tail -f log/development-backend.log'
alias deskstart='work; foreman start'
alias deskkill='killall ruby; killall nginx'
alias deskcleares='work; rake assistly:es:index:remove_all; rake assistly:es:index:build; rake assistly:es:index:prune_versions'
alias deskguard='work; guard'
function rubytest() {
  export REPORTER=spec,failtest;
  RAILS_ENV=test time bundle exec ruby ${1}
}
function deskonetest() {
  export REPORTER=spec,failtest;
  RAILS_ENV=test time rake assistly:test:${2:-units} TEST=${1} ${3}
}
function unit() {
  export REPORTER=spec,failtest;
  ${2:RAILS_ENV=test} time bundle exec ruby -Ilib:test ${1}
}
function desktest() {
  export REPORTER=progress,failtest,slowtest;
  RAILS_ENV=test rake ci:setup:db;
  xitstatus=-1;
  RAILS_ENV=test time rake assistly:test:all && xitstatus=$?
  if [ $xitstatus -ne 0 ]; then
    osascript -e 'tell application "Terminal" to display alert "Test Failed" buttons "Shucks."'
  else
    osascript -e 'tell application "Terminal" to display alert "Test Passed" buttons "Right on!"'
  fi
  return $xitstatus
}
function set_database() {
  export SPECIFIC_DB="$1"
}

# encryption. assumes you have "gpg" installed via Homebrew
encrypt() {
  gpg -c -z 9 --cipher-algo AES256 --compress-algo BZIP2 $@
}
decrypt() {
  gpg $@
}

# which hack, so it also shows defined aliases and functions that match
function which() {
  type_out=`type "$@"`;
  if [ ! -z "$type_out" ]; then
    echo "$type_out";
  else
    /usr/bin/env which $@;
  fi
}

# universal edit command, points back to your defined $EDITOR
function edit() {
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

# Use LLVM-GCC4.2 as the c compiler
# CC='`xcode-select -print-path`/usr/bin/llvm-gcc-4.2 make'

# requires homebrew's apple-gcc42 installed
export CC=/usr/local/bin/gcc-4.2
export GCC=/usr/local/bin/gcc-4.2
export CXX=/usr/local/bin/gcc-4.2

# Use clang as the c compiler
# CC='/Developer/usr/bin/clang'
# export CC=/opt/local/bin/clang
# export CXX=/opt/local/bin/clang++

# Sexy man pages. Opens a postscript version in Preview.app
pman() { man -t "$@" | open -f -a Preview; }

# Who is holding open this damn port or file??
# usage: portopen 3000
function portopen {
	sudo lsof -P -i ":${1}"
}
function fileopen {
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
alias passenger-restart='work; touch tmp/restart.txt'

# GIT shortcuts
alias gb='git branch'
alias gbnotes='git branch --edit-description'
alias gba='git branch -a'
alias gc='git commit -v'
alias push='git push'
alias pushforce='git push -f'
alias pull='git pull'
alias puff='git puff' # pull --ff-only
alias fetch='git fetch'
alias co='git checkout' # NOTE: overwrites a builtin for RCS (wtf? really? RCS?)
alias checkout='git checkout'
alias gco='git checkout'
alias gpp='git pull;git push'
alias gst='git status'
alias ga='git add -v'
alias gs='git status'
alias gcb='git checkout -b'
alias gitrollback='git reset --hard; git clean -f'
alias gunadd='git reset HEAD'
alias grc='git rebase --continue'

# git functions
function gd {
  git diff ${1} | $EDITOR;
}

function rbr {
 git checkout $1;
 git pull origin $1;
 git checkout $2;
 git rebase $1;
}

function mbr {
 git checkout $1;
 git merge $2
 git push origin $1;
 git checkout $2;
}

# the following depend on the parse_git_branch function defined elsewhere
function rebase_to_latest_master {
  cur=$(parse_git_branch);
  git stash;
  git checkout master;
  git pull origin master;
  git checkout $cur;
  git rebase master;
  git stash pop;
}

# 'git pull origin master' shortcut, but make sure you're on master first!
function gpom {
  cur=$(parse_git_branch);
  if [ $cur = 'master' ]; then
    git pull origin master;
  else
    echo "DUDE! You aren't on master branch!"
  fi
}

function open_all_files_changed_from_master {
  if [ -d .git ]; then
    $EDITOR .
    for file in `git diff --name-only master`
    do
      $EDITOR $file
    done
  else
    echo "Hey man. You're not in a directory with a git repo."
  fi
}

# automated git bisecting. because I hate remembering how to use this.
# ex. usage: git_wtf_happened <ruby testfile> <how many commits back, default 8>
function git_wtf_happened {
  git bisect start HEAD HEAD~${1:-8};
  shift;
  git bisect run $*;
  git bisect view;
  git bisect reset;
}

# git functions and extra config
source ~/bin/git-branch.bash # defines parse_git_branch and parse_git_branch_with_dirty
source ~/bin/git-completion.bash

# Command prompt config
PS1="\[\033[G\]\[$TXTWHT\]\u@\H\[$TXTWHT\]:\[$TXTYLW\]\w \[$NO_COLOR\]\D{%F %T} ${BRIGHT_RED}\$(parse_git_branch_with_dirty)\n\[$TXTPUR\]\# \[$TXTYLW\]${SHELL##*/}>>\[$NO_COLOR\] "
# PS1="${DULL_WHITE}\w${BRIGHT_RED} \$(parse_git_branch)${BRIGHT_WHITE}\$ "

#supercolor
# PS1="\[$(tput rev)\]$PS1\[$(tput sgr0)\]"
# PS1="\[$(tput setaf 1)\]$PS1\[$(tput sgr0)\]"

# IRC hackery
export IRCNICK="lectrick"
export IRCUSER="Any"
export IRCNAME="Peter"
export IRCSERVER="irc.freenode.net"

# RVM integration
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

# silliness
fortune
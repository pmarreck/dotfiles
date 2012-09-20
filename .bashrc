echo "Running .bashrc"
# HOMEBREW CONFIG
# Add Python installed scripts to front of PATH
export PATH=/usr/local/share/python:${PATH/\/usr\/local\/share\/python:/}
# Move /usr/local/bin and /usr/local/sbin to the front of PATH by subbing it out and prepending
export PATH=/usr/local/sbin:${PATH/\/usr\/local\/sbin:/}
export PATH=/usr/local/bin:${PATH/\/usr\/local\/bin:/}

# Experimental "Plan 9 from User Space" PATH config
export PLAN9=/usr/local/plan9
export PATH=$PATH:$PLAN9/bin

# stop checking for unix mail, OS X!
unset MAILCHECK

# tweak to get gcc to not use the LLVM version (because ruby gems hate it for now)
export CC=/usr/bin/gcc-4.2

# assistly/desk specific
export DESK_ROOT=/Users/pmarreck/Sites/assistly
export TEST_ROOT=/Users/pmarreck/Sites/test

# Node.js
export NODE_PATH=/usr/local/lib/node

# Color constants
export NO_COLOR='\e[0m' #disable colors
export TXTBLK='\e[0;30m' # Black - Regular
export TXTRED='\e[0;31m' # Red
export TXTGRN='\e[0;32m' # Green
export TXTYLW='\e[0;33m' # Yellow
export TXTBLU='\e[0;34m' # Blue
export TXTPUR='\e[0;35m' # Purple
export TXTCYN='\e[0;36m' # Cyan
export TXTWHT='\e[0;37m' # White
export BLDBLK='\e[1;30m' # Black - Bold
export BLDRED='\e[1;31m' # Red
export BLDGRN='\e[1;32m' # Green
export BLDYLW='\e[1;33m' # Yellow
export BLDBLU='\e[1;34m' # Blue
export BLDPUR='\e[1;35m' # Purple
export BLDCYN='\e[1;36m' # Cyan
export BLDWHT='\e[1;37m' # White
export UNDBLK='\e[4;30m' # Black - Underline
export UNDRED='\e[4;31m' # Red
export UNDGRN='\e[4;32m' # Green
export UNDYLW='\e[4;33m' # Yellow
export UNDBLU='\e[4;34m' # Blue
export UNDPUR='\e[4;35m' # Purple
export UNDCYN='\e[4;36m' # Cyan
export UNDWHT='\e[4;37m' # White
export BAKBLK='\e[40m'   # Black - Background
export BAKRED='\e[41m'   # Red
export BAKGRN='\e[42m'   # Green
export BAKYLW='\e[43m'   # Yellow
export BAKBLU='\e[44m'   # Blue
export BAKPUR='\e[45m'   # Purple
export BAKCYN='\e[46m'   # Cyan
export BAKWHT='\e[47m'   # White
export TXTRST='\e[0m'    # Text Reset
export BRIGHT_RED="\[\033[1;31m\]"
export DULL_WHITE="\[\033[0;37m\]"
export BRIGHT_WHITE="\[\033[1;37m\]"

PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting

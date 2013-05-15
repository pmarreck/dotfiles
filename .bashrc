echo "Running .bashrc"

source ~/.pathrc

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

# assistly/desk specific
export DESK_ROOT=/Users/pmarreck/Sites/assistly
export SECRET_PROJECT=/Users/pmarreck/Sites/projectX
export TEST_ROOT=/Users/pmarreck/Sites/test

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


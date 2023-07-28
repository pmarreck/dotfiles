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
# OK, thanks to badly written hooks, this now has to be a function
# alias word='grep \!* /usr/share/dict/web2' # Grep thru dictionary
if [ "$PLATFORM" = "osx" ]; then
  alias tophog='top -ocpu -s 3'
else # linux
  alias tophog='top -o %CPU -d 3'
fi

# NixOS-specific stuff
if [ "${PLATFORM}-${DISTRO}" = "linux-NixOS" ]; then
  alias nix-list-gens='sudo nix-env -p /nix/var/nix/profiles/system --list-generations'
  alias nix-gen-num='readlink /nix/var/nix/profiles/system | cut -d- -f2'
  nix-genstamp() {
    echo "$(datetimestamp) generation $(nix-gen-num); nvidia version $(nvidia --version); kernel version $(uname -r)" >> ~/nix-genstamp.txt
  }
  alias nixos="$EDITOR /etc/nixos"
  function abbrev-nix-store-paths(){
    sed -E 's|/nix/store/[a-z0-9]{32}-|/⌘/|g'
  }
fi

#alias wordcount=(cat \!* | tr -s '\''  .,;:?\!()[]"'\'' '\''\012'\'' |' \
#                'cat -n | tail -1 | awk '\''{print $1}'\'')' # Histogram words
# alias js='java org.mozilla.javascript.tools.shell.Main'
alias scr='screen -r'
alias p='ping www.yahoo.com'
alias pp='ping -A -i 5 8.8.4.4' #Ping the root google nameserver every 5 seconds and beep if no route
alias t='btop'
# alias tu='top -ocpu -Otime'
alias bye='logout'

# The current thing(s) I'm working on
alias mpnetwork='cd ~/Documents/mpnetwork*'
alias addigence='cd ~/Documents/addigence-ex'
# alias simpaticio='cd ~/Documents/simpaticio'
alias work=addigence

alias dotfiles='cd ~/dotfiles'

# alias ss='script/server'
# alias sc='script/console'
# alias rc='rails console'

# network crap (OS X only)
if [ "$PLATFORM" = "osx" ]; then
  alias killdns='sudo killall -HUP mDNSResponder'
fi

# elixir/phoenix gigalixir prod deploy command
needs git
alias deploy_prod='git push gigalixir master'
alias deploy_staging='git push gigalixir staging:master'

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
alias get='wget --xattr --show-progress -c -q -O - --'
alias getfile='wget --xattr --show-progress -c -q --'

alias consoleconfig='code $WEZTERM_CONFIG_FILE'

# quick CLI editor shortcut
alias e='micro'

# why is grep dumb?
# alias grep='egrep'

# forkbomb!
# alias forkbomb=':(){ :|:& };:'

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
alias gd='git diff'
alias gcb='git checkout -b'
alias gitrollback='git reset --hard; git clean -f'
alias gunadd='git reset HEAD'
alias grc='git rebase --continue'
alias fetch='git fetch' # --all --prune'

# lines of code counter
# brew install tokei
alias loc='tokei'

# homebrew utils
# alias bubu='brew update && brew upgrade'

# fun
alias chuck="curl -sS https://api.chucknorris.io/jokes/random | jq -c -r '.value'"

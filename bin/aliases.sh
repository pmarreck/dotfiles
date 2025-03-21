####### Aliases

alias_permanently() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  case "$1" in
    *=*)
      # split on the first '='
      local name="${1%%=*}"
      local value="${1#*=}"
      # escape any single quotes in the value
      value="${value//\'/\\\'}"
      # if we have a value, then we're defining an alias
      if [ -n "$value" ]; then
        local comment=""
        # if we have a comment, then add it
        if [ -n "$2" ]; then
          local comment="# $2"
        fi
        # check if the alias already exists
        if [ -z "$(alias "$name" 2>/dev/null)" ]; then
          # if it doesn't, then add it
          local alias_definition="alias $name='$value'"
          if [ -n "$comment" ]; then
            echo "$comment" >> "$BASH_SOURCE"
          fi
          echo "$alias_definition" >> "$BASH_SOURCE"
          echo "$alias_definition $comment"
          eval "$alias_definition"
        else
          echo "Alias $name already exists"
          return 1
        fi
      fi
      ;;
    *)
      echo "Usage: alias_permanently alias_name='alias_definition' ['optional comment']"
      ;;
  esac
} && export -f alias_permanently

# get the list of defined aliases
alias aliases='alias'

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
alias _ldefault='eza --long --hyperlink --header --all --icons --git --sort'
alias l='_ldefault name'
alias le='l -@'
alias lsize='_ldefault size --total-size -r'
alias l0='l --git-ignore --tree'
alias le0='le --git-ignore --tree'
alias lsize0='lsize --git-ignore --tree'
alias l1='l0 --level=1'
alias le1='le0 --level=1'
alias lsize1='lsize0 --level=1'
alias l2='l0 --level=2'
alias le2='le0 --level=2'
alias lsize2='lsize0 --level=2'
alias l3='l0 --level=3'
alias le3='le0 --level=3'
alias lsize3='lsize0 --level=3'
alias l4='l0 --level=4'
alias le4='le0 --level=4'
alias lsize4='lsize0 --level=4'
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
if [ "${PLATFORM}-${DISTRO}" = "linux-NixOS" ] || is_nix_darwin; then
  alias nix-list-gens='sudo nix-env -p /nix/var/nix/profiles/system --list-generations'
  alias nix-gen-num='readlink /nix/var/nix/profiles/system | cut -d- -f2'
  nix-genstamp() {
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    echo "$(datetimestamp) generation $(nix-gen-num); nvidia version $(nvidia --version); kernel version $(uname -r)" >> ~/nix-genstamp.txt
  } && export -f nix-genstamp
  is_nix_darwin || alias nixos="choose_editor /etc/nixos &"
  function abbrev-nix-store-paths(){
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    $SED -E 's|(/nix/store/)?[a-z0-9]{32}-|/⌘/|g'
  } && export -f abbrev-nix-store-paths
fi

#alias wordcount=(cat \!* | tr -s '\''  .,;:?\!()[]"'\'' '\''\012'\'' |' \
#                'cat -n | tail -1 | awk '\''{print $1}'\'')' # Histogram words
# alias js='java org.mozilla.javascript.tools.shell.Main'
alias scr='screen -r'
alias p='ping www.yahoo.com'
alias pp='ping -A -i 5 8.8.4.4' #Ping the root google nameserver every 5 seconds and beep if no route
# alias tu='top -ocpu -Otime'
alias bye='logout'

# The current thing(s) I'm working on
# on macos, iCloud backup was interfering with git, so I moved git repos
# to a "Documents-CloudManaged" folder
if [ "$PLATFORM" = "osx" ]; then
  alias dcm='cd ~/Documents-CloudManaged'
  alias mpnetwork='cd ~/Documents-CloudManaged/mpnetwork'
else
  alias dcm='cd ~/Documents'
  alias mpnetwork='cd ~/Documents/mpnetwork'
fi
# alias simpaticio='cd ~/Documents/simpaticio'
alias work=dotfiles

alias dotfiles='cd ~/dotfiles'

alias configs='cd ~/.config'

alias config="choose_editor $XDG_CONFIG_HOME"

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
alias get='wget --xattr -c --progress=bar -O - --'
# but also sometimes just download a file as-is
alias getfile='wget --xattr -c --progress=bar --'
# wanted to add the ability to handle multiple files...
getfiles() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  for url in "$@"; do
    getfile "$url"
  done
} && export -f getfiles

alias newsshkey='ssh-keygen -t ed25519 -C lumbergh@gmail.com'
alias copysshpubkey='cat ~/.ssh/id_ed25519.pub | clip' # depends on 'clip' function
alias consoleconfig='edit $WEZTERM_CONFIG_FILE'

# quick CLI editor shortcut
needs micro "please install the micro editor"
alias e='choose_editor'

# why is grep dumb?
# alias grep='egrep'

# forkbomb!
# alias forkbomb=':(){ :|:& };:'

# z-library attribution removal from filename
# Since I usually leave globbing off, but need it on here, this checks globbing state
# and restores it to whatever it was after, cleaning up after itself.
# alias remove_z_library_attrib='rsg="+"; if [[ $- == *f* ]]; then rsg="-"; fi; set +f; for file in *\ \(Z-Library\).*; do mv "$file" "${file/ (Z-Library)/}"; done; set ${rsg}f; unset rsg'
# ...Converted to a function in .bashrc, kept here for posterity

# GIT shortcuts
needs git "please install git"
alias gb='git branch'
# alias gbnotes='git branch --edit-description'
# alias gba='git branch -a'
alias gc='git commit -v'
alias push='git push'
# alias pushforce='git push -f'
alias pull='git pull --rebase'
alias puff='git pull --ff-only'
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
alias gcob='git checkout -b'
alias gitrollback='git reset --hard; git clean -f'
alias gunadd='git reset HEAD'
alias grc='git rebase --continue'
alias fetch='git fetch' # --all --prune'
alias fetchall='git fetch --all --prune'

# lines of code counter
# brew install tokei
needs tokei "please install tokei"
alias loc='tokei'

alias procs=list-procs

alias gcai=git_commit_ai
alias gcail=git_commit_ai_local

# homebrew utils
# alias bubu='brew update && brew upgrade'

alias d=show # "view" goes to vim, "s" usually launches a search or server, so "d" (for "define") is a good alias for show IMHO

alias t='supertop'

alias surf='windsurf'

alias rm='rm-safe'

[[ $- == *i* ]] && echo "Running .bashrc"

[[ -s "$HOME/.bash_profile" ]] && source ~/.bash_profile

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

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

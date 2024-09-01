# Who is holding open this damn port or file??
# usage: portopen 3000
# May only work on OS X and need tweaking for Linux!
portopen() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  case $PLATFORM in
    "osx")
      >&2 echo -e "${ANSI}${TXTYLW}sudo lsof -P -i \":${1}\"${ANSI}${TXTDFT}"
      sudo lsof -P -i ":${1}"
      ;;
    *) # assumed to be linux; needs ripgrep
      >&2 echo -e "${ANSI}${TXTYLW}sudo netstat -tulpn | rg --color never \"(:${1}|Address)\"${ANSI}${TXTDFT}"
      sudo netstat -tulpn | rg --color never "(:${1}|Address)"
      ;;
  esac
}
fileopen() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  case $PLATFORM in
    "osx")
      >&2 echo -e "${ANSI}${TXTYLW}sudo lsof \"${1}\"${ANSI}${TXTDFT}"
      sudo lsof "${1}" 2>/dev/null
      ;;
    *) # assumed to be linux; needs ripgrep
      >&2 echo -e "${ANSI}${TXTYLW}sudo lsof | rg --color never \"${1}\"${ANSI}${TXTDFT}"
      sudo lsof | rg --color never "${1}" 2>/dev/null
      ;;
  esac
}
fileopen_offenders() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # list top 10 file-open offenders
  >&2 echo -e "${ANSI}${TXTYLW}sudo lsof | awk '{print \$1}' | sort | uniq -c | sort -nr | head${ANSI}${TXTDFT}"
  sudo lsof | awk '{print $1}' | sort | uniq -c | sort -nr | head
}

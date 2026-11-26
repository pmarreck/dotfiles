# Sexy man pages. Opens a postscript version in Preview.app on OS X or evince on Linux
if [ "$OS" = "macos" ]; then
  pman() { 
    [ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    man -t "$@" | open -f -a Preview
  }
elif [ "$OS" = "linux" ]; then
  # unfortunately this is a little grosser on linux, requiring a tempfile
  pman() {
    [ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    needs evince provided by evince package
    tmpfile=$(mktemp --tmpdir --suffix=.pdf "${1}.XXXXXX")
    man -Tpdf "$@" >> $tmpfile 2>/dev/null
    evince $tmpfile
  }
fi

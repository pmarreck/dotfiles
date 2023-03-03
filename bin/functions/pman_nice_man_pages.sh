# Sexy man pages. Opens a postscript version in Preview.app on OS X or evince on Linux
if [ "$PLATFORM" = "osx" ]; then
  pman() { man -t "$@" | open -f -a Preview; }
elif [ "$PLATFORM" = "linux" ]; then
  # unfortunately this is a little grosser on linux, requiring a tempfile
  pman() {
    needs evince provided by evince package
    tmpfile=$(mktemp --suffix=.pdf /tmp/$1.XXXXXX)
    man -Tpdf "$@" >> $tmpfile 2>/dev/null
    evince $tmpfile
  }
fi

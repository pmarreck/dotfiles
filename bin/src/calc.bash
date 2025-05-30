# do simple math in the shell
# example: calc 2+2
# note that 'calc 4 * 23' will fail due to globbing, but 'calc 4*23' or 'calc "4 * 23"' will work
# EDIT: Turned globbing off globally; to force globbing, use the "expand" function now. So `calc 4 * 23` works fine.
# calc "define fac(x) { if (x == 0) return (1); return (fac(x-1) * x); }; fac(5)"
if needs bc ; then
  calc() {
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    local scale=${SCALE:-10}
    local old_bcll
    [[ -n "${BC_LINE_LENGTH}" ]] && old_bcll=$BC_LINE_LENGTH
    export BC_LINE_LENGTH=${BC_LINE_LENGTH:-0}
    # echo "$*"
    local bcscript=""
    if read -t 0; then
      read -d '' -r bcscript
    else
      if [[ $# > 0 ]]; then
        bcscript="$*"
      else
        read -d '' -r bcscript # last resort, just try stdin again
      fi
    fi
    # trim leading and trailing whitespace
    bcscript="${bcscript##+([[:space:]])}"
    if [[ -z "$bcscript" ]]; then
      fail "calc's input looks blank."
      return 1
    fi
    # format function definitions per bc requirements
    # ok so bc *requires* a newline after an open brace, but it *doesn't* require a newline before a close brace
    # so we have to do this weird thing where we replace all newlines with spaces, then replace all spaces after an open brace with a newline
    bcscript=$(echo -e "$bcscript" | sed -e 's/\n+/ /g' -e 's/{\s*/{\n/g' -e 's/} *;?/}\n/g' -e 's/;/\n/g')
    [ -n "$DEBUG" ] && puts -e --stderr "string received by calc:\n'$bcscript'"
    echo -e "scale=${scale}\n$bcscript" | bc -l
    local retcode=$?
    if [[ "$old_bcll" != '' ]]; then # it was set before and its old value is that
      BC_LINE_LENGTH=$old_bcll
    else
      unset BC_LINE_LENGTH # it wasn't originally set, so unset it now
    fi
    return $retcode
  }

  if ${RUN_DOTFILE_TESTS:-false}; then
    assert "$(calc 2*4)" == 8 "simple calculations with calc should work"
    assert "$(calc 4 * 23)" == 92 "simple calculations with calc should not glob (requires globbing to be off)"
    assert "$(calc "define fac(x) { if (x == 0) return (1); return (fac(x-1) * x); }; fac(5)")" == 120 "recursive functions with calc should work"
    assert "$(puts "define fac(x) { if (x == 0) return (1); return (fac(x-1) * x); }; fac(5)" | calc)" == 120 "piping into calc should work"
  fi
else
  fail "bc is not installed; can't define calc function." 0
fi

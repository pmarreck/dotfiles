
# For the Ruby fans.
# Floating point seconds since epoch, to nanosecond resolution.
Time.now.to_f() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # set the date bin to gdate (or one that recognizes --resolution) if available
  local datebin="date"
  $datebin --resolution >/dev/null 2>&1 || datebin="gdate"
  $datebin --resolution >/dev/null 2>&1 || datebin="date"
  # use perl for timestamps if the date timestamp resolution isn't small enough
  local _use_perl_for_more_accurate_timestamps=0
  if [ "$($datebin --resolution)" != "0.000000001" ]; then
    _use_perl_for_more_accurate_timestamps=1
  fi
  if [ $_use_perl_for_more_accurate_timestamps -eq 1 ]; then
    perl -MTime::HiRes=time -e 'printf "%.9f\n", time'
  else
    $datebin +'%s.%N'
  fi
}
export -f Time.now.to_f

# Nanoseconds since unix epoch.
# Might be cheap just to strip the decimal, but there's always a fixed number of digits to the right of the decimal
now_in_ns() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local now=$(Time.now.to_f)
  echo ${now//.}
}
export -f now_in_ns

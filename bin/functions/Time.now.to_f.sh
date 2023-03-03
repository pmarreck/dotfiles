# use perl for timestamps if the date timestamp resolution isn't small enough
_use_perl_for_more_accurate_timestamps=0
if [ "$($datebin --resolution)" != "0.000000001" ]; then
  _use_perl_for_more_accurate_timestamps=1
fi
# For the Ruby fans.
# Floating point seconds since epoch, to nanosecond resolution.
Time.now.to_f() {
  if [ $_use_perl_for_more_accurate_timestamps -eq 1 ]; then
    perl -MTime::HiRes=time -e 'printf "%.9f\n", time'
  else
    $datebin +'%s.%N'
  fi
}

# Nanoseconds since unix epoch.
# Might be cheap just to strip the decimal, but there's always a fixed number of digits to the right of the decimal
now_in_ns() {
  local now=$(Time.now.to_f)
  echo ${now//.}
}

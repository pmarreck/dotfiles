# Lets you time different parts of your bash code consecutively to see where slowdowns are occurring.
# Usage example:
# note_time_diff --start
# ... one or more commands ...
# note_time_diff "some note about the previous command"
# ... more commands ...
# note_time_diff
# ... more commands ...
# note_time_diff --end
note_time_diff() {
  case $1 in
  --start)
    _start_time=$(Time.now.to_f)
    _interstitial_time=$_start_time
    echo "timestart: $_start_time"
    ;;
  --end)
    local _end_time=$(Time.now.to_f)
    local totaltimediff=$(echo "scale=10;$_end_time - $_start_time" | bc)
    local timediff=$(echo "scale=10;$_end_time - $_interstitial_time" | bc)
    echo "timediff: $timediff"
    echo "time_end: $_end_time"
    echo "totaltimediff: $totaltimediff"
    unset _start_time
    unset _interstitial_time
    ;;
  *)
    local _now=$(Time.now.to_f)
    local timediff=$(echo "scale=10;$_now - $_interstitial_time" | bc)
    echo "timediff: $timediff $1"
    _interstitial_time=$_now
    ;;
  esac
}

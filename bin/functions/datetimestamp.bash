
# set the date bin to gdate (or one that recognizes --resolution) if available
datebin=date
$datebin --resolution >/dev/null 2>&1 || datebin=gdate
$datebin --resolution >/dev/null 2>&1 || datebin=date
datetimestamp() {
  local format=${DATETIMESTAMPFORMAT:-'+%Y%m%d%H%M%S'}
  # if there is a --date argument
  case "$1" in
    --date=*|-d=*)
      $datebin --date="${1#*=}" "$format"
      ;;
    --date|-d)
      $datebin --date="$2" "$format"
      ;;
    --help|-h)
      echo "Usage: datetimestamp [--date|-d[=| ]'date']"
      echo "  --date|-d [date]  date to use, defaults to now, see man date for format details"
      echo "  --help|-h         show this help"
      return 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      datetimestamp -h
      return 2
      ;;
    *)
      $datebin "$format"
      ;;
  esac
}
source_relative_once assert.bash

assert "$(datetimestamp --date='@2147483640')" == 20380118221400 "datetimestamp should work as expected and pad zeroes"
assert "$(DATETIMESTAMPFORMAT='+%Y-%m-%d %H:%M:%S' datetimestamp --date='@2147483640')" == \
       "2038-01-18 22:14:00" "datetimestamp should take an env format string with a space"

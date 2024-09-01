# get current weather, output as big ASCII art
weather() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs curl
  needs jq
  needs bc
  needs figlet # note that on ubuntu derivatives, this is shortcutted by default to "toilet"? Um, no. So check that.
  if [ -z "$OPENWEATHERMAP_APPID" ]; then
    echo "OPENWEATHERMAP_APPID is not set. Get an API key from http://openweathermap.org/appid and set it in your environment."
    return 1
  fi
  # lat and lon are set for port washington, ny
  # look them up at: http://www.latlong.net/
  temp=`curl -s "http://api.openweathermap.org/data/2.5/weather?lat=40.82658&lon=-73.68312&appid=$OPENWEATHERMAP_APPID" | jq .main.temp`
  # echo "temp in kelvin is: $temp"
  temp=$(bc <<< "$temp*9/5-459.67") # convert from kelvin to F
  echo "$temp F" | figlet -kcf big
}
# my openweathermap key did not work after I created it... time delay?
# EDIT: Works now
# But returns Kelvin. Don't have time to figure out F from K in Bash using formula F = K * 9/5 - 459.67
# EDIT 2: Figured that out

# get the current FANCY (not just ANSI🤣) weather. wttr.in has tons of URL options, check out their site:
# https://github.com/chubin/wttr.in
weatherfancy() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  curl wttr.in
}

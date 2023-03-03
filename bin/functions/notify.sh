# personal push notifications
# example usage:
# notify 'It works!'
# (Use single quotes to avoid having to escape all punctuation but single quote)

notify() {
  curl -s -F "token=$PUSHOVER_NOTIFICATION_TOKEN" \
  -F "user=$PUSHOVER_NOTIFICATION_USER" \
  -F "message=$1" https://api.pushover.net/1/messages.json
  # -F "title=YOUR_TITLE_HERE" \
}

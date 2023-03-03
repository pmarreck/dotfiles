

# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
>/dev/null declare -F needs || \
needs() {
  local bin=$1
  shift
  command -v $bin >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

# Command line access to the ChatGPT API
ask() {
  needs jq
  needs glow see https://github.com/charmbracelet/glow
  local request response response_parsed args
  args="$*"
  args=$(printf "%b" "$args" | jq -sRr '@json') # json value escaping
# printf "escaped args: %s\n" "$args" >&2
  # note that gpt-3.5-turbo-0301 is the very latest model as of 2021-03-01 but will only be supported for a few weeks
  read -r -d '' request <<EOF
  curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  --silent \
  --max-time 10 \
  -d '{"model": "gpt-3.5-turbo-0301", "messages": [{"role": "user", "content": $args}]}'
EOF
# printf "request: %s\n" "$request" >&2
  response=$(eval $request)
# printf "response: %s\n" "$response" >&2
  response_parsed=$(printf "%s" "$response" | jq --raw-output '.choices[0].message.content')
  if [[ "$response_parsed" == "null" || "$?" != "0" ]]; then
    printf "Error:\n" >&2
    printf "%b" "$response" >&2
    printf "%b" "$response_parsed"
  else
    printf "%s" "$response_parsed" | sed -e 's/^[\\n]\+//' -e 's/^[\n]\+//' | glow -
  fi
}

# IMPORTANT!
# how do we even test this function? Pass in a mocked curl somehow?

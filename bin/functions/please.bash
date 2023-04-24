#!/usr/bin/env bash

# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
>/dev/null declare -F needs || \
needs() {
  local bin=$1
  shift
  command -v "$bin" >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

_generate_curl_api_request_for_please() {
  needs jq
  local request args timeout model curl
  curl=${CURL:-curl}
  model=${OPENAI_MODEL:-gpt-3.5-turbo-0301} # other options: gpt-4, gpt-4-0314, gpt-4-32k, gpt-4-32k-0314, gpt-3.5-turbo, gpt-3.5-turbo-0301
  timeout=${OPENAI_TIMEOUT:-15}
  args="$@"
  args=$(printf "%b" "$args" | sed "s/'/'\\\\''/g") # This is just a narsty sed to escape single quotes.
  # (Piping to "jq -sRr '@json'" was not working correctly, so I had to take control of the escaping myself.)
# printf "escaped args: %b\n" "$args" >&2
  # note that gpt-3.5-turbo-0301 is the very latest model as of 2021-03-01 but will only be supported for a few weeks
  read -r -d '' request <<EOF
  $curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  --silent \
  --max-time $timeout \
  -d '{"model": "$model", "messages": [{"role": "user", "content": "$args"}], "temperature": 0.7}'
EOF
  printf "%b" "$request"
}

please() {
  needs curl
  needs jq
  needs gum from https://github.com/charmbracelet/gum
  local request response response_parsed response_parsed_cleaned args
  request=$(_generate_curl_api_request_for_please "What is the linux bash command to $@? Only return the command to run itself, do not describe anything. Only use commands and executables that are common on most Linux systems.")
# printf "request: %s\n" "$request" >&2 
  response=$(eval "gum spin --show-output -s line --title \"Figuring out how to do this...\" -- $request")
# printf "response: %s\n" "$response" >&2
  response_parsed=$(printf "%s" "$response" | jq --raw-output '.choices[0].message.content')
# printf "response_parsed: %s\n" "$response_parsed" >&2
  if [[ "$response_parsed" == "null" || "$?" != "0" ]]; then
    printf "Error:\n" >&2
    printf "%b\n" "$response" >&2
    printf "%b\n" "$response_parsed"
  else
    response_parsed_cleaned=$(printf "%s" "$response_parsed" | sed -e 's/^[\\n]\+//' -e 's/^[\n]\+//')
    printf "\e[0;33m%s\n\e[m" "$response_parsed_cleaned" >&2
    printf "%s" "$response_parsed_cleaned" | bash
  fi
}

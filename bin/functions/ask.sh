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

_generate_curl_api_request_for_ask() {
  needs jq
  local request args timeout
  timeout=${ASK_TIMEOUT:-15}
  args="$*"
  args=$(printf "%b" "$args" | jq -sRr '@json') # json value escaping for quotes, etc
# printf "escaped args: %s\n" "$args" >&2
  # note that gpt-3.5-turbo-0301 is the very latest model as of 2021-03-01 but will only be supported for a few weeks
  read -r -d '' request <<EOF
  curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  --silent \
  --max-time $timeout \
  -d '{"model": "gpt-3.5-turbo-0301", "messages": [{"role": "user", "content": $args}]}'
EOF
  printf "%s" "$request"
}

# Command line access to the ChatGPT API
needs curl # this call is outside the function so that it can be mocked properly

ask() {
  needs jq
  needs glow see https://github.com/charmbracelet/glow
  local response response_parsed args
  request=$(_generate_curl_api_request_for_ask "$*")
# printf "request: %s\n" "$request" >&2
  response=$(eval "$request")
  # response="bogus"
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
source_relative_once bin/functions/assert.bash
source_relative_once bin/functions/utility_functions.bash

# TEST SETUP
shopt -q extglob && extglob_set=true || extglob_set=false
shopt -s extglob

# mock out curl
curl() {
  case "$1" in
  ?(What is the connection between)*)
    cat <<EOF | trim_leading_heredoc_whitespace | collapse_whitespace_containing_newline_to_single_space
      {"id":"chatcmpl-6q7qCBoIJGlRldK97GQrLAcfOqXwS","object":"chat.completion",
      "created":1677881216,"model":"gpt-3.5-turbo-0301","usage":{"prompt_tokens":29,
      "completion_tokens":96,"total_tokens":125},"choices":[{"message":{"role":"assistant",
      "content":"\n\nThere is no direct connection between \"The Last Question\" and
       \"The Last Answer\" by Isaac Asimov. \"The Last Answer\" is a short story about
       a man who searches for the meaning of life and death, while \"The Last Question\"
       is a science fiction story that explores the concept of the end of the universe and
       the possibility of creating a new one. However, both stories deal with philosophical
       themes about the nature of existence and the ultimate fate of humanity."},
      "finish_reason":null,"index":0}]}
EOF
  ;;
  *)
    printf "Error: mocked curl was called with unexpected arguments: %s\n" "$*" >&2
    return 1
  ;;
  esac
}

# assert "$(ltrim "$(ask 'What is the connection between "The Last Question" and "The Last Answer" by Isaac Asimov?')" | head -n1)" =~ "connection"

# TEST TEARDOWN
unset -f curl # unmock curl
$extglob_set || shopt -u extglob # restore extglob setting
unset extglob_set
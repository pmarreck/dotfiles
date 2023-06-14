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

# Command line access to the ChatGPT API
ask() {
  needs curl
  needs jq
  needs glow see https://github.com/charmbracelet/glow
  local request response response_parsed args
  request=$(_generate_curl_api_request_for_ask "$@")
  response=$(eval "$request")
# printf "request: %s\n" "$request" >&2
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

source_relative_once datetimestamp.bash
# Uses the OpenAI image generation API to generate an image from a prompt
# and output it to the terminal via the sixel protocol.
# Example usage: imagine a cow jumping over the moon
imagine() {
  needs convert Please install ImageCraptastick I mean ImageMagick
  local prompt geometry create_img url rand_num stamp filename response maybe_error
  prompt="$@"
  geometry=${GEOMETRY:-512x512} # options: 256x256, 512x512, or 1024x1024
  create_img=$(curl https://api.openai.com/v1/images/generations -s \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "{\"prompt\": \"$prompt\", \"n\": 1, \"size\": \"$geometry\"}"
  )
  if echo "$create_img" | jq -e '.error' >/dev/null; then
    echo -n "Error: " >&2
    echo "$create_img" | jq -r '.error.message' >&2
    return 1
  fi
  (( DEBUG )) && echo $create_img | jq >&2
  url=$(echo $create_img | jq -r '.data[0].url')
  # rand_num=$(shuf -i 1-1000000 -n 1)
  stamp=$(DATETIMESTAMPFORMAT="+%Y%m%d%H%M%S%N" datetimestamp)
  filename=$(mktemp -t "img-${stamp}-XXXX" --suffix .png)
  response=$(curl -s $url -o "$filename")
  (( DEBUG )) && echo "debug: $response" >&2
  convert "$filename" -geometry $geometry sixel:-
  echo "This image is currently stored temporarily at: $filename" >&2
}

# IMPORTANT!
# how do we even test this function? Pass in a mocked curl somehow?
source_relative_once assert.bash
source_relative_once utility_functions.bash

# TEST SETUP
shopt -q extglob && extglob_set=true || extglob_set=false
shopt -s extglob

# mock out curl
mocked_curl() {
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

# TESTS
resp=$(CURL=mocked_curl ask What is the connection between "The Last Question" and "The Last Answer" by Isaac Asimov?)
# echo "response in test: $resp"
assert "$resp" =~ "connection"

# TEST TEARDOWN
unset -f mocked_curl # unmock curl
$extglob_set || shopt -u extglob # restore extglob setting
unset extglob_set

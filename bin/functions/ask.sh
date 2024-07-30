#!/usr/bin/env bash

# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
# >/dev/null declare -F needs || \
needs() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin=$1
  shift
  command -v "$bin" >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

# Command line access to the ChatGPT API
ask() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs curl
  needs jq
  needs glow see https://github.com/charmbracelet/glow
  local model request response timeout diff temp_json temp_json_out commit_message http_status \
    openai_host openai_path openai_protocol openai_url local_llm \
    top_k top_p temperature system_prompt user_prompt repeat_penalty num_ctx
  model=${OPENAI_MODEL:-gpt-4o} # other options: gpt-3.5-turbo, gpt-3.5-turbo-1106, gpt-4, gpt-4-0314, gpt-4-32k, gpt-4-32k-0314
  timeout=${OPENAI_TIMEOUT:-60}
  openai_host=${OPENAI_HOST:-api.openai.com}
  openai_path=${OPENAI_PATH:-/v1/chat/completions}
  openai_protocol=${OPENAI_PROTOCOL:-https}
  openai_url=${OPENAI_URL:-${openai_protocol}://${openai_host}${openai_path}}
  top_k=${TOP_K:-40}
  top_p=${TOP_P:-0.9}
  repeat_penalty=${REPEAT_PENALTY:-1.1}
  temperature=${TEMPERATURE:-0.2}
  num_ctx=${NUM_CTX:-32000}
  temp_json=$(mktemp -t ask.XXXXXX --tmpdir)
  temp_json_out=$(mktemp -t ask.XXXXXX --tmpdir)
  system_prompt="You are a helpful AI assistant."
  user_prompt="$*"
  curl=${CURL:-curl}
  local_llm=false
  if [[ "$openai_host" == localhost* ]]; then
    local_llm=true
  fi
  if $local_llm; then
    jq -n --arg model "$model" \
          --argjson top_k "$top_k" \
          --argjson top_p "$top_p" \
          --argjson repeat_penalty "$repeat_penalty" \
          --argjson temperature "$temperature" \
          --argjson num_ctx "$num_ctx" \
          --arg system_prompt "$system_prompt" \
          --arg user_prompt "$user_prompt" \
      '{
      model: $model,
      options: {
        temperature: $temperature,
        top_k: $top_k,
        top_p: $top_p,
        num_ctx: $num_ctx,
        repeat_penalty: $repeat_penalty
      },
      messages: [
        {role: "system", content: $system_prompt},
        {role: "user", content: "\($user_prompt)\n"}
      ],
      max_tokens: 1000,
      stream: false
    }' > "$temp_json"
  else # openAI
    # jq --null-input \
    # --arg model "$model" \
    # --arg text "$*" \
    # '{"model": $model, "messages": [{"role": "user", "content": $text}], "top_p": 0.3}' > "$temp_json"
    jq -n --arg model "$model" \
          --argjson top_k "$top_k" \
          --argjson top_p "$top_p" \
          --argjson repeat_penalty "$repeat_penalty" \
          --argjson temperature "$temperature" \
          --argjson num_ctx "$num_ctx" \
          --arg system_prompt "$system_prompt" \
          --arg user_prompt "$user_prompt" \
      '{
      model: $model,
      messages: [
        {role: "system", content: $system_prompt},
        {role: "user", content: "\($user_prompt)\n"}
      ],
      temperature: $temperature,
      max_tokens: 1000,
      stream: false
    }' > "$temp_json"
  fi
# set -x
  http_status=$($curl -w "%{http_code}" -s -o "$temp_json_out" -X POST $openai_url \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --silent \
    --max-time $timeout \
    -d "@$temp_json")
# echo "http_status: $http_status" >&2
  if [[ "$http_status" -ne 200 ]]; then
    echo "Error: API request failed with status code $http_status." >&2
    echo "Response:" >&2
    cat "$temp_json_out" >&2
    return 1
  fi
# echo "file path: $temp_json_out" >&2
# cat "$temp_json_out" >&2
  response=$(jq -r '.choices[0].message.content' < "$temp_json_out" 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//')
  if [[ "$response" == "null" ]]; then
    response=$(jq -r '.message.content' < "$temp_json_out" | sed 's/^[ \t]*//;s/[ \t]*$//')
  fi
# printf "response: %s\n" "$response" >&2
  # response_parsed=$(printf "%s" "$response" | jq --raw-output '.choices[0].message.content')
  if [[ "$response" == "null" || "$?" != "0" ]]; then
    printf "Error:\n" >&2
    printf "%b" "$response" >&2
  else
    printf "%s" "$response" | sed -e 's/^[\\n]\+//' -e 's/^[\n]\+//' | glow -
  fi
}

export DEFAULT_LOCAL_AI_MODEL="llama3.1:70b"
export DEFAULT_LOCAL_AI_HOST="localhost:11434"

function ask_local() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  OPENAI_MODEL="$DEFAULT_LOCAL_AI_MODEL" \
  OPENAI_HOST="$DEFAULT_LOCAL_AI_HOST" \
  OPENAI_PATH="/api/chat" \
  OPENAI_PROTOCOL="http" \
  OPENAI_API_KEY="fake" \
  OPENAI_TIMEOUT=600 \
  ask "$@"
}

source_relative_once datetimestamp.bash
# Uses the OpenAI image generation API to generate an image from a prompt
# and output it to the terminal via the sixel protocol.
# Example usage: imagine a cow jumping over the moon
imagine() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
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

if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
  # IMPORTANT!
  # how do we even test this function? Pass in a mocked curl somehow?
  source_relative_once assert.bash
  source_relative_once utility_functions.bash

  # TEST SETUP
  shopt -q extglob && extglob_set=true || extglob_set=false
  shopt -s extglob

  # mock out curl
  mocked_curl() {
    [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
      # http_status=$($curl -w "%{http_code}" -s -o "$temp_json_out" -X POST $openai_url \
      # -H "Content-Type: application/json" \
      # -H "Authorization: Bearer $OPENAI_API_KEY" \
      # --silent \
      # --max-time $timeout \
      # -d "@$temp_json")
    local output_file
    while getopts ":o:w:X:H:d:s" opt; do
      case ${opt} in
      o )
        output_file=$OPTARG
        # echo "output_file: $output_file" >&2
        ;;
      ? )
        ;;
      : )
      echo "Option -$OPTARG requires an argument." >&2
        ;;
      esac
    done
    cat <<EOF | trim_leading_heredoc_whitespace | collapse_whitespace_containing_newline_to_single_space > "$output_file"
      {"id":"chatcmpl-6q7qCBoIJGlRldK97GQrLAcfOqXwS","object":"chat.completion",
      "created":1677881216,"model":"test-model","usage":{"prompt_tokens":29,
      "completion_tokens":96,"total_tokens":125},"choices":[{"message":{"role":"assistant",
      "content":"\n\nThere is no direct connection between \"The Last Question\" and\n\"The Last Answer\" by Isaac Asimov. \"The Last Answer\" is a short story about\na man who searches for the meaning of life and death, while \"The Last Question\"\nis a science fiction story that explores the concept of the end of the universe and\nthe possibility of creating a new one. However, both stories deal with philosophical\nthemes about the nature of existence and the ultimate fate of humanity."},
      "finish_reason":null,"index":0}]}
EOF
    echo 200 # assumes http_code was the curl format parameter
  }

  # TESTS
  resp=$(CURL=mocked_curl ask "What is the connection between \"The Last Question\" and \"The Last Answer\" by Isaac Asimov?")
  # echo "response in test: '$resp'"
  assert "$resp" =~ "connection"

  # TEST TEARDOWN
  unset -f mocked_curl # unmock curl
  $extglob_set || shopt -u extglob # restore extglob setting
  unset extglob_set
fi

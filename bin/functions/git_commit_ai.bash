#!/usr/bin/env bash

function git_commit_ai() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if [[ -z "$OPENAI_API_KEY" ]]; then
    echo "OPENAI_API_KEY is not defined." >&2
    return 1
  fi

  local model request response timeout diff temp_json temp_json_out commit_message http_status \
    openai_host openai_path openai_protocol openai_url local_llm \
    top_k top_p temperature
  diff=$(git diff)
  if [[ -z "$diff" ]]; then
    diff=$(git diff --cached)
  fi
  if [[ -z "$diff" ]]; then
    echo "No changes to commit." >&2
    return 1
  fi

  model=${OPENAI_MODEL:-gpt-4-1106-preview}
  timeout=${OPENAI_TIMEOUT:-60}
  openai_host=${OPENAI_HOST:-api.openai.com}
  openai_path=${OPENAI_PATH:-/v1/chat/completions}
  openai_protocol=${OPENAI_PROTOCOL:-https}
  openai_url=${OPENAI_URL:-${openai_protocol}://${openai_host}${openai_path}}
  top_k=${TOP_K:-40}
  top_p=${TOP_P:-0.9}
  temperature=${TEMPERATURE:-0.7}
  temp_json=$(mktemp -t git_commit_ai.XXXXXX --tmpdir)
  temp_json_out=$(mktemp -t git_commit_ai.XXXXXX --tmpdir)
  # trap 'rm -f "$temp_json" && rm -f "$temp_json_out' EXIT # ensure temp file is cleaned up on exit

  local_llm=false
  if [[ "$openai_host" == "localhost*" ]]; then
    local_llm=true
  fi
  if $local_llm; then
    jq -n --arg model "$model" --arg diff "$diff" --argjson top_k "$top_k" --argjson top_p "$top_p" --argjson temperature "$temperature" '{
      model: $model,
      messages: [
        {role: "system", content: "You are a senior developer who hates writing markdown- plaintext or GTFO!"},
        {role: "user", content: "Generate a concise git commit command and message(s) for the following git diff. DO NOT use markdown or triple backticks and do not editorialize. ONLY output the git command. If you need to use multiple comment lines, separate them into separate `-m` arguments to git. If there does not appear to be diff data, please say so instead:\n\n\($diff)\n\nNow generate the correct `git commit` command for the above changes: "}
      ],
      options: {
        temperature: $temperature,
        top_k: $top_k,
        top_p: $top_p
      },
      max_tokens: 150,
      stream: false
    }' > "$temp_json"
  else # openAI
    jq -n --arg model "$model" --arg diff "$diff" --argjson top_k "$top_k" --argjson top_p "$top_p" --argjson temperature "$temperature" '{
      model: $model,
      messages: [
        {role: "system", content: "You are a senior developer who hates writing markdown- plaintext or GTFO!"},
        {role: "user", content: "Generate a concise git commit command and message(s) for the following git diff. DO NOT use markdown or triple backticks and do not editorialize. ONLY output the git command. If you need to use multiple comment lines, separate them into separate `-m` arguments to git. If there does not appear to be diff data, please say so instead:\n\n\($diff)\n\nNow generate the correct `git commit` command for the above changes: "}
      ],
      temperature: $temperature,
      max_tokens: 150,
      stream: false
    }' > "$temp_json"
  fi

# cat "$temp_json" >&2

# echo curl -w \"%{http_code}\" -s -o \"$temp_json_out\" -X POST $openai_url \
#     -H \"Content-Type: application/json\" \
#     -H \"Authorization: Bearer $OPENAI_API_KEY\" \
#     --silent \
#     --max-time \"$timeout\" \
#     -d \"@$temp_json\"

  http_status=$(curl -w "%{http_code}" -s -o "$temp_json_out" -X POST $openai_url \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --silent \
    --max-time "$timeout" \
    -d "@$temp_json")

  if [[ "$http_status" -ne 200 ]]; then
    echo "Error: API request failed with status code $http_status." >&2
    echo "Response:" >&2
    cat "$temp_json_out" >&2
    return 1
  fi

  response=$(jq -r '.choices[0].message.content' < "$temp_json_out" 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//')
  if [[ "$response" == "null" ]]; then
    response=$(jq -r '.message.content' < "$temp_json_out" | sed 's/^[ \t]*//;s/[ \t]*$//')
  fi
  commit_message="$response"

  if [[ "$(uname)" == "Darwin" ]]; then
    echo -ne "$commit_message" | pbcopy
  else # assume linux if not macos
    echo -ne "$commit_message" | xclip -selection clipboard
  fi

  echo "Commit command copied to clipboard:" >&2
  echo -ne "$commit_message"
}

function git_commit_ai_local() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  OPENAI_MODEL="codellama:34b-code" \
  OPENAI_HOST="localhost:11434" \
  OPENAI_PATH="/api/chat" \
  OPENAI_PROTOCOL="http" \
  OPENAI_API_KEY="fake" \
  git_commit_ai
}

alias gcai=git_commit_ai
alias gcail=git_commit_ai_local

#!/usr/bin/env bash

function git_commit_ai() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if [[ -z "$OPENAI_API_KEY" ]]; then
    echo "OPENAI_API_KEY is not defined." >&2
    return 1
  fi

  local model request response timeout diff temp_json commit_message http_status
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
  temp_json=$(mktemp -t git_commit_ai.XXXXXX --tmpdir)
  trap 'rm -f "$temp_json"' EXIT # ensure temp file is cleaned up on exit

  jq -n --arg model "$model" --arg diff "$diff" '{
    model: $model,
    messages: [
      {role: "system", content: "You are a senior developer."},
      {role: "user", content: "Generate a concise git commit command and message(s) for the following git diff. Do not use markdown or triple backticks and do not editorialize. Only output the command. If you need to use multiple comment lines, separate them into separate `-m` arguments to git. If there does not appear to be diff data, please say so instead:\n\n\($diff)\n\nCommit message: "}
    ],
    max_tokens: 150,
    n: 1,
    stop: null,
    temperature: 0.7
  }' > "$temp_json"

  http_status=$(curl -w "%{http_code}" -s -o "$temp_json" -X POST https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --silent \
    --max-time "$timeout" \
    -d "@$temp_json")

  if [[ "$http_status" -ne 200 ]]; then
    echo "Error: API request failed with status code $http_status." >&2
    echo "Response:" >&2
    cat "$temp_json" >&2
    return 1
  fi

  response=$(jq -r '.choices[0].message.content' < "$temp_json" | sed 's/^[ \t]*//;s/[ \t]*$//')
  commit_message="$response"

  if [[ "$(uname)" == "Darwin" ]]; then
    echo -ne "$commit_message" | pbcopy
  else # assume linux if not macos
    echo -ne "$commit_message" | xclip -selection clipboard
  fi

  echo "Commit command copied to clipboard:" >&2
  echo -ne "$commit_message"
}

alias gcai=git_commit_ai

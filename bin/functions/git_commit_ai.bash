#!/usr/bin/env bash

git_commit_ai() {
  if ! defined? OPENAI_API_KEY; then
    echo "OPENAI_API_KEY is not defined." >&2
    return 1
  fi
  local model request response timeout diff temp_json message
  diff=$(git diff)
  if [[ -z "$diff" ]]; then
    diff=$(git diff --cached)
  fi
  if [[ -z "$diff" ]]; then
    echo "No changes to commit." >&2
    return 1
  fi
  model=${ASK_MODEL:-gpt-3.5-turbo-0301};
  timeout=${ASK_TIMEOUT:-15}
  temp_json=$(mktemp)
  jq -n --arg model "$model" --arg diff "$diff" '{
    model: $model,
    messages: [
      {role: "system", content: "You are a senior developer."},
      {role: "user", content: "Generate a commit message for the following git diff. If there does not appear to be diff data, please say so instead:\n\n\($diff)\n\nCommit message: "}
    ],
    max_tokens: 150,
    n: 1,
    stop: null,
    temperature: 0.7
  }' > "$temp_json"
  response=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --silent \
    --max-time "$timeout" \
    -d "@$temp_json")
  response=$(printf '%s' "$response" | jq -r '.choices[0].message.content' | sed 's/^[ \t]*//;s/[ \t]*$//')
  message=$response
  [ -f "$temp_json" ] && rm "$temp_json"

  if [[ "$(uname)" == "Darwin" ]]; then
    echo -n "git commit -m \"$message\"" | pbcopy
  else
    echo -n "git commit -m \"$message\"" | xclip -selection clipboard
  fi

  echo "Commit command copied to clipboard:"
  echo "git commit -m \"$message\""
}
alias gcai=git_commit_ai

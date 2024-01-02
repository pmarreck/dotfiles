#!/usr/bin/env bash

function git_commit_ai() {
  [ -v EDIT ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  if [[ -z "$OPENAI_API_KEY" ]]; then
    echo "OPENAI_API_KEY is not defined." >&2
    return 1
  fi

  local model request response timeout diff temp_json temp_json_out commit_message http_status \
    openai_host openai_path openai_protocol openai_url local_llm \
    top_k top_p temperature system_prompt user_prompt repeat_penalty num_ctx
  diff=$(git diff)
  if [[ -z "$diff" ]]; then
    diff=$(git diff --cached)
  fi
  if [[ -z "$diff" ]]; then
    echo "No changes to commit." >&2
    return 1
  fi

  model=${OPENAI_MODEL:-gpt-4-1106-preview}
  timeout=${OPENAI_TIMEOUT:-1200}
  openai_host=${OPENAI_HOST:-api.openai.com}
  openai_path=${OPENAI_PATH:-/v1/chat/completions}
  openai_protocol=${OPENAI_PROTOCOL:-https}
  openai_url=${OPENAI_URL:-${openai_protocol}://${openai_host}${openai_path}}
  top_k=${TOP_K:-40}
  top_p=${TOP_P:-0.9}
  repeat_penalty=${REPEAT_PENALTY:-1.1}
  temperature=${TEMPERATURE:-0.2}
  num_ctx=${NUM_CTX:-32000}
  temp_json=$(mktemp -t git_commit_ai.XXXXXX --tmpdir)
  temp_json_out=$(mktemp -t git_commit_ai.XXXXXX --tmpdir)
  system_prompt="You are a helpful coding AI assistant. You always output plaintext without markdown."
  user_prompt="Output only the git commit command for the following git diff. Do not include any markdown formatting, triple backticks, discussion, or description. Provide the command in plain text, exactly as it should be entered in a command-line interface. If multiple lines of commit messages are required, use separate '-m' arguments to git. If no diff data is present, state 'No diff data'."
  # trap 'rm -f "$temp_json" && rm -f "$temp_json_out' EXIT # ensure temp file is cleaned up on exit

  local_llm=false
  if [[ "$openai_host" == localhost* ]]; then
    local_llm=true
  fi
# echo "openai_host: $openai_host" >&2
# echo "local_llm: $local_llm" >&2
  if $local_llm; then
    jq -n --arg model "$model" \
          --arg diff "$diff" \
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
        {role: "user", content: "\($user_prompt)\n\nBEGIN GIT DIFF\n\($diff)\nEND GIT DIFF\n"}
      ],
      max_tokens: 200,
      stream: false
    }' > "$temp_json"
  else # openAI
    jq -n --arg model "$model" \
          --arg diff "$diff" \
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
        {role: "user", content: "\($user_prompt)\n\nBEGIN GIT DIFF\n\($diff)\nEND GIT DIFF\n"}
      ],
      temperature: $temperature,
      max_tokens: 200,
      stream: false
    }' > "$temp_json"
  fi

# cat "$temp_json" >&2
# echo >&2
# echo curl -w \"%{http_code}\" -s -o \"$temp_json_out\" -X POST $openai_url \
#     -H \"Content-Type: application/json\" \
#     -H \"Authorization: Bearer $OPENAI_API_KEY\" \
#     --silent \
#     --max-time $timeout \
#     -d \"@$temp_json\" >&2
# echo >&2

  http_status=$(curl -w "%{http_code}" -s -o "$temp_json_out" -X POST $openai_url \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --silent \
    --max-time $timeout \
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
  OPENAI_MODEL="dolphin-mixtral:latest" \
  OPENAI_HOST="localhost:11434" \
  OPENAI_PATH="/api/chat" \
  OPENAI_PROTOCOL="http" \
  OPENAI_API_KEY="fake" \
  git_commit_ai
}

alias gcai=git_commit_ai
alias gcail=git_commit_ai_local

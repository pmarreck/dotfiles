#!/usr/bin/env bash

# Shared function to get bot-detection-resistant curl arguments for specific sites
# Returns appropriate curl arguments based on the site's anti-bot measures

get_curl_args() {
  local url="$1"

  # Build a dynamic Referer from the passed-in URL, prepending https:// if missing
  local ref="$url"
  if [[ ! "$ref" =~ ^https?:// ]]; then
    ref="https://$ref"
  fi

  # Include compression and HTTP/2, along with sec-fetch headers and a realistic UA. Single-line to avoid eval issues.
	local DEFAULT_CURL_ARGS="--http2 --compressed -H \"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8\" -H \"Accept-Language: en-US,en;q=0.9\" -H \"Cache-Control: no-cache\" -H \"Pragma: no-cache\" -H \"Sec-Fetch-Dest: document\" -H \"Sec-Fetch-Mode: navigate\" -H \"Sec-Fetch-Site: none\" -H \"Sec-Fetch-User: ?1\" -H \"Sec-Ch-Ua: \\\"Chromium\\\";v=\\\"130\\\", \\\"Google Chrome\\\";v=\\\"130\\\", \\\"Not?A_Brand\\\";v=\\\"99\\\"\" -H \"Sec-Ch-Ua-Mobile: ?0\" -H \"Sec-Ch-Ua-Platform: \\\"macOS\\\"\" -H \"Upgrade-Insecure-Requests: 1\" -H \"Connection: keep-alive\" -H \"Referer: $ref\" -A \"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36\""

	# The following currently works for all of them.
	echo "${DEFAULT_CURL_ARGS}"

  # # Site-specific headers to bypass different bot detection systems.
	# # Most (if not all) currently default to DEFAULT_CURL_ARGS once I found a set of headers
	# # that worked across most of them, but leaving the logical branching in place
	# # in case I have to modify again in the future.
  # if [[ "$url" == *"facebook.com"* ]] || [[ "$url" == *"meta.com"* ]]; then
  #   # Facebook requires Safari headers - they block Chrome/Firefox user agents
  #   # echo '-A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"'
  #   echo "${DEFAULT_CURL_ARGS}"
  # elif [[ "$url" == *"chatgpt.com"* ]]; then
  #   # ChatGPT (Cloudflare + strict bot detection). Emulate a modern Chrome request with full headers
  #   echo "${DEFAULT_CURL_ARGS}"
  # else
  #   # Default Chrome headers work for most sites including ChatGPT, X, etc.
  #   echo "${DEFAULT_CURL_ARGS}"
  #   # echo '--http2 --compressed -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" -H "Accept-Language: en-US,en;q=0.9" -H "Sec-Ch-Ua: \"Chromium\";v=\"130\", \"Google Chrome\";v=\"130\", \"Not?A_Brand\";v=\"99\"" -H "Sec-Ch-Ua-Mobile: ?0" -H "Sec-Ch-Ua-Platform: \"macOS\"" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"'
  # fi
}

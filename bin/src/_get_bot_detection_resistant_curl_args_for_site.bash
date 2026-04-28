#!/usr/bin/env bash

# Shared function to get bot-detection-resistant curl arguments for specific sites.
#
# Output protocol: one argument per line on stdout. Callers read with:
#   declare -a CURL_ARGS=()
#   while IFS= read -r line; do CURL_ARGS+=("$line"); done < <(get_curl_args "$url")
#   curl ... "${CURL_ARGS[@]}" "$url"
#
# This avoids `eval` and the quote-fragility of "args as a single string."

get_curl_args() {
	local url="$1"

	# Build a dynamic Referer from the passed-in URL, prepending https:// if missing
	local ref="$url"
	if [[ ! "$ref" =~ ^https?:// ]]; then
		ref="https://$ref"
	fi

	# Default args: HTTP/2, compression, sec-fetch headers, realistic Chrome UA.
	# Each printf positional becomes one line on stdout — one argv element for the caller.
	printf '%s\n' \
		'--http2' \
		'--compressed' \
		'-H' 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8' \
		'-H' 'Accept-Language: en-US,en;q=0.9' \
		'-H' 'Cache-Control: no-cache' \
		'-H' 'Pragma: no-cache' \
		'-H' 'Sec-Fetch-Dest: document' \
		'-H' 'Sec-Fetch-Mode: navigate' \
		'-H' 'Sec-Fetch-Site: none' \
		'-H' 'Sec-Fetch-User: ?1' \
		'-H' 'Sec-Ch-Ua: "Chromium";v="130", "Google Chrome";v="130", "Not?A_Brand";v="99"' \
		'-H' 'Sec-Ch-Ua-Mobile: ?0' \
		'-H' 'Sec-Ch-Ua-Platform: "macOS"' \
		'-H' 'Upgrade-Insecure-Requests: 1' \
		'-H' 'Connection: keep-alive' \
		'-H' "Referer: $ref" \
		'-A' 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'

	# Site-specific branching can be added here in the future. Default Chrome
	# headers above currently work for all configured sites.
}

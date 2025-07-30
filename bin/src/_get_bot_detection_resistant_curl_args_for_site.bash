#!/usr/bin/env bash

# Shared function to get bot-detection-resistant curl arguments for specific sites
# Returns appropriate curl arguments based on the site's anti-bot measures

get_curl_args() {
	local url="$1"

	# Site-specific headers to bypass different bot detection systems
	if [[ "$url" == *"facebook.com"* ]] || [[ "$url" == *"meta.com"* ]]; then
		# Facebook requires Safari headers - they block Chrome/Firefox user agents
		echo '-A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"'
	else
		# Default Chrome headers work for most sites including ChatGPT, X, etc.
		echo '--http2 -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" -H "Accept-Language: en-US,en;q=0.9" -H "Sec-Ch-Ua: \"Chromium\";v=\"130\", \"Google Chrome\";v=\"130\", \"Not?A_Brand\";v=\"99\"" -H "Sec-Ch-Ua-Mobile: ?0" -H "Sec-Ch-Ua-Platform: \"macOS\"" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"'
	fi
}

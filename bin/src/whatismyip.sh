whatismyip() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	needs awk "Please install awk"
	if command -v ifconfig >/dev/null 2>&1; then
		if [[ "$(uname)" == "Darwin" ]]; then
			# macOS
			ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
		else
			# Linux
			ip=$(ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
		fi
	elif command -v ip >/dev/null 2>&1; then
		# Modern Linux systems
		ip=$(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
	else
		echo "Neither ifconfig nor ip command is available."
		return 1
	fi

	if [[ -z "$ip" ]]; then
		echo "Could not determine local IP address." >&2
		return 1
	else
		echo "$ip"
	fi
}

whatismyexternalip() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	needs curl "Please install curl"

	# Array of IP service endpoints that return just the IP
	local services=(
		"https://api.ipify.org"
		"https://ifconfig.me/ip"
		"https://icanhazip.com"
		"https://ident.me"
	)

	local ip=""
	local timeout=5  # Timeout in seconds for each request

	# Try each service until we get a valid IP
	for service in "${services[@]}"; do
		if ip=$(curl -s --max-time "$timeout" "$service" 2>/dev/null); then
			# Validate IP format (basic check)
			if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
				echo "$ip"
				return 0
			fi
		fi
	done

	echo "Could not determine external IP address." >&2
	return 1
}

whatismyipv6() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	if command -v ifconfig >/dev/null 2>&1; then
		if [[ "$(uname)" == "Darwin" ]]; then
			# macOS - filter for global IPv6 addresses (2000::/3)
			ip=$(ifconfig | grep "inet6 " | grep -v "::1" | grep "^.*2" | awk '{print $2}' | head -n1)
		else
			# Linux - same but with different grep pattern
			ip=$(ifconfig | grep -oP '(?<=inet6\s)2[0-9a-fA-F:]+' | head -n1)
		fi
	elif command -v ip >/dev/null 2>&1; then
		# Modern Linux systems
		ip=$(ip -6 addr show | grep -oP '(?<=inet6\s)2[0-9a-fA-F:]+' | head -n1)
	else
		echo "Neither ifconfig nor ip command is available."
		return 1
	fi
	if [[ -z "$ip" ]]; then
		echo "Could not determine global IPv6 address." >&2
		return 1
	else
		echo "$ip"
	fi
}

whatismyexternalipv6() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
	needs curl "Please install curl"

	local services=(
		"https://api64.ipify.org"
		"https://ifconfig.co/ip"
		"https://v6.ident.me"
	)

	local ip=""
	local timeout=5

	for service in "${services[@]}"; do
		if ip=$(curl -6 -s --max-time "$timeout" "$service" 2>/dev/null); then
			# Validate IPv6 format (basic check for at least one colon)
			if [[ $ip == *:* ]]; then
				echo "$ip"
				return 0
			fi
		fi
	done

	echo "Could not determine external IPv6 address." >&2
	return 1
}

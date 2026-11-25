#!/usr/bin/env bash

_macos_ssh_agent_is_socket() { [ -S "$1" ]; }

# Remote macOS shells may lack the GUI login's agent environment. Reuse its
# already-loaded keys without unlocking Keychain or starting another agent.
configure_macos_ssh_agent_env() {
	case "${1:-${OSTYPE:-}}" in darwin*) ;; *) return 0 ;; esac
	[ -z "${SSH_AUTH_SOCK:-}" ] || return 0
	local service_info socket
	service_info=$(launchctl print "gui/$(id -u)/com.openssh.ssh-agent" 2>/dev/null) || return 0
	socket=$(printf '%s\n' "$service_info" | awk '
		$1 == "SSH_AUTH_SOCK" && $2 == "=>" {
			sub(/^[[:space:]]*SSH_AUTH_SOCK[[:space:]]*=>[[:space:]]*/, "")
			print; exit
		}')
	[ -n "$socket" ] && _macos_ssh_agent_is_socket "$socket" || return 0
	export SSH_AUTH_SOCK="$socket"
}

#!/usr/bin/env bash

# Persistent Linux terminals (tmux, a long-lived terminal server) can outlive
# the desktop login that set DISPLAY and WAYLAND_DISPLAY. Recover them from the
# systemd user manager for a local GUI request. Never replace a display that is
# already set, and never act over SSH, where any display belongs to another
# machine. Assigns in the caller's scope: declare DISPLAY and WAYLAND_DISPLAY
# local (and exported) first to keep the recovery temporary.
recover_desktop_display() {
	[[ -z "${SSH_CONNECTION:-}" && -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] || return 0
	[[ "$(uname -s)" == Linux ]] || return 0
	local desktop_env line
	desktop_env="$(systemctl --user show-environment 2>/dev/null)" || desktop_env=""
	while IFS= read -r line; do
		case "$line" in
			DISPLAY=*) DISPLAY="${line#DISPLAY=}" ;;
			WAYLAND_DISPLAY=*) WAYLAND_DISPLAY="${line#WAYLAND_DISPLAY=}" ;;
		esac
	done <<< "$desktop_env"
	return 0
}

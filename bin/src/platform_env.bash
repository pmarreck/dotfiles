#!/usr/bin/env bash

# Canonicalize execution-platform facts for shell startup. With no arguments,
# facts come from the running kernel. Three arguments make the pure mapping
# reusable by callers that already have OS, architecture, and kernel identity.

_platform_env_normalize_os() {
	case "$1" in
		[Ll][Ii][Nn][Uu][Xx]*) printf '%s' linux ;;
		[Dd][Aa][Rr][Ww][Ii][Nn]*) printf '%s' macos ;;
		[Mm][Ss][Yy][Ss]*|[Mm][Ii][Nn][Gg][Ww]*|[Cc][Yy][Gg][Ww][Ii][Nn]*|[Ww][Ii][Nn][Dd][Oo][Ww][Ss]*)
			printf '%s' mswin
			;;
		*)
			printf 'platform_env: unsupported operating system: %s\n' "$1" >&2
			return 1
			;;
	esac
}

_platform_env_normalize_arch() {
	case "$1" in
		[Xx]86_64|[Aa][Mm][Dd]64) printf '%s' amd64 ;;
		[Aa][Aa][Rr][Cc][Hh]64|[Aa][Rr][Mm]64) printf '%s' arm64 ;;
		*)
			printf 'platform_env: unsupported architecture: %s\n' "$1" >&2
			return 1
			;;
	esac
}

configure_platform_env() {
	local raw_os raw_arch kernel_identity canonical_os canonical_arch canonical_pf canonical_wsl
	if (( $# == 0 )); then
		raw_os=$(uname -s) || return
		raw_arch=$(uname -m) || return
		kernel_identity=$(uname -r) || return
	elif (( $# == 3 )); then
		raw_os=$1
		raw_arch=$2
		kernel_identity=$3
	else
		printf 'platform_env: expected zero or three arguments, got %s\n' "$#" >&2
		return 2
	fi

	canonical_os=$(_platform_env_normalize_os "$raw_os") || return
	canonical_arch=$(_platform_env_normalize_arch "$raw_arch") || return
	canonical_pf="$canonical_os-$canonical_arch"
	case "$canonical_pf" in
		macos-arm64|linux-amd64|linux-arm64|mswin-amd64|mswin-arm64) ;;
		*)
			printf 'platform_env: unsupported platform: %s\n' "$canonical_pf" >&2
			return 1
			;;
	esac

	canonical_wsl=0
	if [ "$canonical_os" = linux ]; then
		case "$kernel_identity" in
			*[Mm][Ii][Cc][Rr][Oo][Ss][Oo][Ff][Tt]*|*[Ww][Ss][Ll]*) canonical_wsl=1 ;;
		esac
	fi

	OS=$canonical_os
	ARCH=$canonical_arch
	PLATFORM=$canonical_pf
	PF=$canonical_pf
	WSL=$canonical_wsl
	export OS ARCH PLATFORM PF WSL
}

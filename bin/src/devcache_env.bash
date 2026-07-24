#!/usr/bin/env bash

# Route reproducible compiler state to NVMe while keeping each repository's
# local build cache isolated; a dataset sentinel prevents HDD fallback.
configure_devcache_env() {
	local cache_root="${1:-${DEVCACHE_ROOT:-/mnt/devcache}}"
	local working_dir="${2:-$PWD}"
	local project_root project_name project_digest project_key

	[ -f "$cache_root/.devcache-ready" ] || return 0

	project_root="$working_dir"
	if command -v git >/dev/null 2>&1; then
		project_root=$(git -C "$working_dir" rev-parse --show-toplevel 2>/dev/null) || project_root="$working_dir"
	fi
	project_root=$(cd "$project_root" 2>/dev/null && pwd -P) || return 0
	project_name="${project_root##*/}"
	if command -v sha256sum >/dev/null 2>&1; then
		project_digest=$(printf '%s' "$project_root" | sha256sum)
	elif command -v shasum >/dev/null 2>&1; then
		project_digest=$(printf '%s' "$project_root" | shasum -a 256)
	else
		project_digest=$(printf '%s' "$project_root" | cksum)
	fi
	project_digest="${project_digest%% *}"
	project_key="${project_name}-${project_digest:0:12}"

	export DEVCACHE_ROOT="$cache_root"
	export CARGO_TARGET_DIR="$cache_root/projects/$project_key/cargo-target"
	export ZIG_GLOBAL_CACHE_DIR="$cache_root/zig/global"
	export ZIG_LOCAL_CACHE_DIR="$cache_root/projects/$project_key/zig-local"
}

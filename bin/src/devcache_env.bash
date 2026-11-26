#!/usr/bin/env bash

# Route reproducible compiler state to NVMe while keeping each checkout's
# local build cache isolated; a dataset sentinel prevents HDD fallback.
#
# Zig's local cache is not exported as ZIG_LOCAL_CACHE_DIR. An exported path
# is inherited by every child process, including one that builds a different
# checkout (`cd other && zig build`, a git worktree, a session started
# elsewhere). Zig 0.16 then reuses that cache's outputs for the other
# checkout's sources whenever the files that produced them are unchanged, so
# the build silently runs the wrong code. Instead, a Zig checkout's own
# `.zig-cache` becomes a symlink to its NVMe directory: Zig finds the cache
# from the build root, so it always matches the checkout being built, and a
# checkout without the link falls back to a private on-disk cache.
devcache_managed_zig_link() {
	local link="$1" cache_root="$2" target
	[ -L "$link" ] || return 1
	target=$(readlink -- "$link") || return 1
	case "$target" in
		"$cache_root"/projects/*/zig-local) return 0 ;;
	esac
	return 1
}

devcache_link_zig_cache() {
	local project_root="$1" cache_root="$2" target="$3"
	local link="$project_root/.zig-cache" exclude

	[ -f "$project_root/build.zig" ] || return 0
	if [ -L "$link" ]; then
		# A copied checkout carries its source's link; repoint it so the two
		# never share one cache. Links this policy did not make are left alone.
		devcache_managed_zig_link "$link" "$cache_root" || return 0
		[ "$(readlink -- "$link")" = "$target" ] && return 0
		mkdir -p -- "$target" 2>/dev/null || return 0
		ln -sfn -- "$target" "$link" 2>/dev/null || return 0
	elif [ -e "$link" ]; then
		return 0 # an existing private cache directory stays in use
	else
		mkdir -p -- "$target" 2>/dev/null || return 0
		ln -s -- "$target" "$link" 2>/dev/null || return 0
	fi
	# Projects commonly ignore `.zig-cache/`, which matches only directories.
	exclude=$(git -C "$project_root" rev-parse --git-path info/exclude 2>/dev/null) || return 0
	case "$exclude" in /*) ;; *) exclude="$project_root/$exclude" ;; esac
	if ! grep -qxF '/.zig-cache' "$exclude" 2>/dev/null; then
		mkdir -p -- "${exclude%/*}" 2>/dev/null && printf '/.zig-cache\n' >> "$exclude" 2>/dev/null
	fi
	return 0
}

configure_devcache_env() {
	local cache_root="${1:-${DEVCACHE_ROOT:-/mnt/devcache}}"
	local working_dir="${2:-$PWD}"
	local project_root project_name project_digest project_key

	# A managed local cache path, inherited or left by an older policy, would
	# point a build at another checkout's cache; drop it in every state.
	case "${ZIG_LOCAL_CACHE_DIR:-}" in
		"$cache_root"/projects/*/zig-local) unset ZIG_LOCAL_CACHE_DIR ;;
	esac

	project_root="$working_dir"
	if command -v git >/dev/null 2>&1; then
		project_root=$(git -C "$working_dir" rev-parse --show-toplevel 2>/dev/null) || project_root="$working_dir"
	fi
	project_root=$(cd "$project_root" 2>/dev/null && pwd -P) || project_root=""

	if [ ! -f "$cache_root/.devcache-ready" ]; then
		[ "${DEVCACHE_ROOT:-}" = "$cache_root" ] && unset DEVCACHE_ROOT
		case "${CARGO_TARGET_DIR:-}" in
			"$cache_root"/projects/*/cargo-target) unset CARGO_TARGET_DIR ;;
		esac
		[ "${ZIG_GLOBAL_CACHE_DIR:-}" = "$cache_root/zig/global" ] && unset ZIG_GLOBAL_CACHE_DIR
		# A link into the unavailable pool would fail every build; removing the
		# link (never its target) restores the private-cache fallback.
		if [ -n "$project_root" ] && devcache_managed_zig_link "$project_root/.zig-cache" "$cache_root"; then
			command rm -f -- "$project_root/.zig-cache" 2>/dev/null
		fi
		return 0
	fi

	[ -n "$project_root" ] || return 0
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
	devcache_link_zig_cache "$project_root" "$cache_root" "$cache_root/projects/$project_key/zig-local"
}

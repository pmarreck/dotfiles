#!/usr/bin/env bash
# Find the LuaJIT that shell startup's engine runs on, before PATH exists.
# Sourced by .pathconfig; spawns nothing unless LuaJIT is missing entirely.
#
# shell_startup_resolve_luajit ROOT [LUAJIT_CANDIDATE...] [--nix NIX_CANDIDATE...]
#
# Sets _SHELL_STARTUP_LUAJIT to an executable LuaJIT and returns 0, or prints a
# message and returns 1. Search order:
#   1. SHELL_STARTUP_LUAJIT, when set (a broken pin fails; it is never replaced)
#   2. each LUAJIT_CANDIDATE (the host's Nix profile locations)
#   3. ROOT/bin/luajit, a GC-rooted copy an earlier bootstrap fetched
#   4. luajit on PATH
#   5. warn, then fetch nixpkgs#luajit with Nix (found on PATH, then among the
#      NIX_CANDIDATEs) into ROOT, so later shells find it at step 3
_shell_startup_first_on_path() { # <name>: sets _SHELL_STARTUP_FOUND, no fork
	local directory
	local -a directories
	_SHELL_STARTUP_FOUND=
	IFS=: read -r -a directories <<<"$PATH"
	for directory in "${directories[@]}"; do
		[ -n "$directory" ] || continue
		if [ -f "$directory/$1" ] && [ -x "$directory/$1" ]; then
			_SHELL_STARTUP_FOUND="$directory/$1"
			return 0
		fi
	done
	return 1
}

shell_startup_resolve_luajit() {
	local root=$1 candidate nix_bin='' in_nix=false
	local -a luajit_candidates=() nix_candidates=()
	shift
	for candidate in "$@"; do
		if [ "$candidate" = --nix ]; then in_nix=true
		elif $in_nix; then nix_candidates+=("$candidate")
		else luajit_candidates+=("$candidate")
		fi
	done
	_SHELL_STARTUP_LUAJIT=

	if [ -n "${SHELL_STARTUP_LUAJIT-}" ]; then
		if [ -x "$SHELL_STARTUP_LUAJIT" ]; then
			_SHELL_STARTUP_LUAJIT=$SHELL_STARTUP_LUAJIT
			return 0
		fi
		printf '%s\n' ".pathconfig: SHELL_STARTUP_LUAJIT=$SHELL_STARTUP_LUAJIT is not an executable LuaJIT; PATH was left unchanged. Unset it to let startup find or fetch one." >&2
		return 1
	fi
	for candidate in "${luajit_candidates[@]}" "$root/bin/luajit"; do
		if [ -f "$candidate" ] && [ -x "$candidate" ]; then
			_SHELL_STARTUP_LUAJIT=$candidate
			return 0
		fi
	done
	if _shell_startup_first_on_path luajit; then
		_SHELL_STARTUP_LUAJIT=$_SHELL_STARTUP_FOUND
		return 0
	fi

	if _shell_startup_first_on_path nix; then
		nix_bin=$_SHELL_STARTUP_FOUND
	else
		for candidate in "${nix_candidates[@]}"; do
			if [ -x "$candidate" ]; then nix_bin=$candidate; break; fi
		done
	fi
	if [ -z "$nix_bin" ]; then
		printf '%s\n' ".pathconfig: neither LuaJIT nor Nix was found; PATH was left unchanged. Install Nix, then open a new shell or run: . ~/.pathconfig" >&2
		return 1
	fi
	printf '%s\n' "Warning: LuaJIT was not found, so shell startup is fetching nixpkgs#luajit with Nix into $root before continuing. Later shells reuse it; adding luajit to this host's Nix configuration makes this unnecessary." >&2
	# A bootstrap PATH may lack coreutils; Nix creates the out-link's parents itself.
	if _shell_startup_first_on_path mkdir; then "$_SHELL_STARTUP_FOUND" -p "${root%/*}" 2>/dev/null; fi
	if ! "$nix_bin" --extra-experimental-features 'nix-command flakes' build --out-link "$root" nixpkgs#luajit >&2 ||
		[ ! -x "$root/bin/luajit" ]; then
		printf '%s\n' ".pathconfig: fetching LuaJIT with Nix failed; PATH was left unchanged. Retry with: . ~/.pathconfig" >&2
		return 1
	fi
	_SHELL_STARTUP_LUAJIT="$root/bin/luajit"
}

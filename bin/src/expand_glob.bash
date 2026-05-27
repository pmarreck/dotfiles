#!/usr/bin/env bash

# expand_glob — expand a glob pattern to matching paths, regardless of the
# shell's current noglob (set -f) state, without depending on programmable
# completion (compgen / complete) builtins.
#
# Why this exists: this repo's shells run with `set -f` (noglob) by default,
# so `matches=( $pattern )` doesn't auto-expand. The old approach used
# `compgen -G`, but Nix's pkgs.bash is a stripped build that omits programmable
# completion — entering any Nix devshell silently strands scripts that rely
# on compgen. This helper uses only core bash (shopt nullglob + parameter
# expansion globbing), available in any bash 4+ build.
#
# State isolation: the subshell parens (...) auto-discard all `set` and `shopt`
# changes on exit, so the caller's noglob/nullglob state survives untouched —
# regardless of what those values were going in. This means the helper keeps
# working correctly even if the global `set -f` convention is ever reversed.
#
# Usage:
#   mapfile -t matches < <(expand_glob "$pattern")
#   mapfile -t matches < <(expand_glob "$pattern" "dotglob globstar")  # extra shopts
#
# Emits one matching path per line on stdout. Emits nothing (zero lines) if
# no matches — compatible with `mapfile -t` (yields empty array).
#
# Optional second arg: space-separated list of additional shopt names to enable
# inside the subshell (e.g., "dotglob" to include dotfiles, "extglob" for
# extended patterns). nullglob is always enabled.
expand_glob() {
	(
		set +f
		shopt -s nullglob
		local _opt
		for _opt in $2; do shopt -s "$_opt"; done
		local IFS=
		local matches=( $1 )
		(( ${#matches[@]} )) && printf '%s\n' "${matches[@]}"
	)
}

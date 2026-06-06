# export_gnu_tool — resolve a GNU-preferred tool ONCE per shell and export
# its full path as an env var, so hot paths can call "$DATE" / "$TAC" /
# "$SHUF" / "$SED" / etc. without paying the wrapper-script fork cost per
# invocation.
#
# Companion to the wrapper scripts under bin/ (bin/tac, bin/shuf, bin/date,
# ...) — wrappers are the transparent backstop for naked-name use; this
# helper gives perf-conscious / internal callers a pre-resolved path.
#
# Usage (in .pathconfig or sourced early in a shell):
#
#   . "$HOME/dotfiles/bin/src/export_gnu_tool.bash"
#   _export_gnu_tool SED  sed  gsed
#   _export_gnu_tool DATE date gdate
#   _export_gnu_tool TAC  tac  gtac
#   _export_gnu_tool SHUF shuf gshuf
#
# Semantics:
#   1. If the named var is already set (even to ""), no-op.
#   2. Prefer the g-prefixed binary if available AND GNU-flavored.
#   3. Otherwise scan plain-name candidates on PATH (skipping anything
#      under $HOME/dotfiles/bin/ — those are our wrappers, which would
#      proxy --version through to GNU and falsely look GNU themselves).
#   4. Pick the first GNU match; if none, fall back to a non-GNU candidate
#      with a one-time stderr warning (suppressible via MUTE_GNU_WRAPPER_WARNINGS=1).
#   5. Return 1 if nothing usable is found anywhere.

_export_gnu_tool() {
	local var="$1" plain="$2" g_prefix="$3"
	# Already set (including to empty string) — respect the caller's choice.
	[ -n "${!var+x}" ] && return 0

	local candidate canonical version_line

	# Prefer g-prefixed (always GNU on this setup; never a wrapper)
	for candidate in $(type -a -p "$g_prefix" 2>/dev/null); do
		version_line=$("$candidate" --version 2>/dev/null | head -1)
		if [[ "$version_line" =~ .*GNU.* ]]; then
			export "$var=$candidate"
			return 0
		fi
	done

	# Fall back to plain-name candidates, but skip our own wrappers — their
	# --version proxies through to GNU and would mislead the detection.
	for candidate in $(type -a -p "$plain" 2>/dev/null); do
		canonical=$(readlink -f "$candidate" 2>/dev/null) || canonical="$candidate"
		case "$canonical" in
			"$HOME/dotfiles/bin/"*) continue ;;
		esac
		version_line=$("$candidate" --version 2>/dev/null | head -1)
		if [[ "$version_line" =~ .*GNU.* ]]; then
			export "$var=$candidate"
			return 0
		fi
	done

	# No GNU found — fall back to first non-wrapper plain candidate, with warning.
	for candidate in $(type -a -p "$plain" 2>/dev/null); do
		canonical=$(readlink -f "$candidate" 2>/dev/null) || canonical="$candidate"
		case "$canonical" in
			"$HOME/dotfiles/bin/"*) continue ;;
		esac
		[ -z "${MUTE_GNU_WRAPPER_WARNINGS:-}" ] && \
			printf '\033[38;5;208mwarning: no GNU %s found on PATH; falling back to %s (set MUTE_GNU_WRAPPER_WARNINGS=1 to silence)\033[0m\n' \
				"$plain" "$candidate" >&2
		export "$var=$candidate"
		return 0
	done

	echo "Error: no $plain or $g_prefix found in PATH" >&2
	return 1
}

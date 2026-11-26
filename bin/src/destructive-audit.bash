# Private, temporary journal shared by the destructive command shadows.

audit_error() {
	printf '%s: %s\n' "$1" "$2" >&2
	return 1
}

audit_root() {
	local root="${TMPDIR:-/tmp}/dotfiles-audit-$EUID" mode
	if [[ ! -e "$root" ]]; then
		mkdir -m 700 -- "$root" 2>/dev/null || [[ -d "$root" ]] || return 1
	fi
	[[ -d "$root" && ! -L "$root" && -O "$root" ]] || return 1
	if [[ "$OSTYPE" == darwin* ]]; then
		mode=$(/usr/bin/stat -f '%Lp' "$root") || return 1
	else
		mode=$(stat -c '%a' -- "$root") || return 1
	fi
	[[ "$mode" == 700 ]] || return 1
	printf '%s\n' "$root"
}

audit_batch() {
	local root timestamp
	root=$(audit_root) || { audit_error "$1" 'private audit directory is unavailable'; return 1; }
	timestamp="${EPOCHREALTIME:-}"
	# The system Bash on macOS predates EPOCHREALTIME. Second-resolution
	# timestamps would order same-second batches by their random suffix.
	[[ -n "$timestamp" ]] || timestamp=$(LC_ALL=C perl -MTime::HiRes=time -e 'printf "%.6f\n", time') || return 1
	mktemp -d "$root/$1-$timestamp.XXXXXXXX"
}

audit_read() (
	local root entry
	root=$(audit_root) || { audit_error "$1" 'private audit directory is unavailable'; exit 1; }
	set +f
	shopt -s nullglob
	for entry in "$root"/"$1"-*/log; do
		[[ -f "$entry" && ! -L "$entry" ]] || continue
		printf '[%s]\n' "${entry%/log}"
		cat -- "$entry" || exit
	done
)

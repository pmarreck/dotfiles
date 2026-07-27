# steam_classify.bash — decide whether a process belongs to Steam/Proton/Wine.
#
# PURE by construction: the only inputs are (comm, exe, argv). No /proc reads, no
# clock, no environment, no process table. Enumeration lives in bin/steam-procs
# and killing in bin/kill-steam-proton-pids; this file is the part that can be
# unit-tested over a fixture corpus with no processes running at all.
#
# WHY NOT ENVIRONMENT (this is the load-bearing comment):
# An earlier version keyed on WINEPREFIX / STEAM_COMPAT_* / SteamAppId, reasoning
# that Wine children carry them regardless of argv. On this host ~/.envconfig
# EXPORTS STEAM_COMPAT_* globally, so every descendant of Peter's shell inherits
# them — that classifier matched 85 processes with Steam dead, including all 14
# Claude agents. Environment is inherited and therefore worthless as evidence of
# what a process IS. Never reintroduce it.
#
# WHY NOT "steam appears in argv" (the heuristic this replaces):
# It misses every Wine helper, whose argv is Windows-style (C:\windows\system32\
# services.exe), and the game itself (argv S:\...\Darktide.exe). It simultaneously
# matches any process merely MENTIONING steam — an editor open on this file, a
# grep, or the invoking `kill-steam-proton-pids` shell itself. Measured against
# the real corpus: 11 of 20 misses and 4 false positives.
#
# The signals used here are ones a process cannot inherit or coincidentally
# acquire: where its executable actually lives, and what the kernel calls it.

# Bash 4 is required for ${var,,}. A silently wrong answer here kills processes,
# so refuse rather than degrade.
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
	echo "steam_classify: requires bash 4+ (found ${BASH_VERSION:-unknown})" >&2
	return 1 2>/dev/null || exit 1
fi

# Installed locations of Steam, its runtimes, and Proton builds. Matched against
# an executable path (authoritative) or a command line (a path ARGUMENT, which is
# far narrower than the bare word "steam" appearing anywhere).
#
# Deliberately absent: a bare "proton" marker. Proton Mail and Proton VPN would
# match it. Every real Proton build lives under /steamapps/ or
# /compatibilitytools.d/, both of which are listed.
_STEAM_PATH_MARKERS=(
	'/steamapps/'
	'/.steam/'
	'/.local/share/steam/'
	'/steamlibrary/'
	'/compatibilitytools.d/'
	'/steamlinuxruntime'
	'/steam-runtime'
	'/pressure-vessel'
)

# Wine's own loader binaries. A process running one of these IS Wine, whatever it
# calls itself — this is the signal that survives a Windows-style argv.
_STEAM_WINE_BINARIES=(
	'wine' 'wine64' 'wineserver' 'wine-preloader' 'wine64-preloader'
	'wineboot' 'winedbg' 'wine-installer'
)

# Returns 0 if a Steam/Proton install path appears in the (already lowercased)
# string. Substring test only — no globbing, no subprocesses.
_steam_has_path_marker() {
	local hay="$1" m
	for m in "${_STEAM_PATH_MARKERS[@]}"; do
		case "$hay" in *"$m"*) return 0 ;; esac
	done
	return 1
}

# steam_proc_match COMM EXE ARGV — rc 0 if the process is Steam/Proton/Wine.
# Sets STEAM_PROC_REASON to the name of the rule that fired (a global rather than
# a subshell so that classifying a few thousand processes costs no forks).
steam_proc_match() {
	STEAM_PROC_REASON=""
	local comm="${1:-}" exe="${2:-}" argv="${3:-}"

	# Kernel threads have an empty command line. They must never match: the
	# kernel's own oom_reaper would otherwise be caught by a rule written for
	# Steam's "reaper", and killing a kernel thread is a no-op at best.
	[ -n "$argv" ] || return 1

	local lcomm="${comm,,}" lexe="${exe,,}" largv="${argv,,}"
	local w base

	# 1. The executable lives inside a Steam library, runtime, or Proton build.
	#    Strongest signal available: a path cannot be inherited from a shell, and
	#    it identifies the game process itself, whose argv reveals nothing.
	if [ -n "$lexe" ] && _steam_has_path_marker "$lexe"; then
		STEAM_PROC_REASON="exe-under-steam-path"
		return 0
	fi

	# 2. The executable IS a Wine loader, wherever it was installed from.
	if [ -n "$lexe" ]; then
		base="${lexe##*/}"
		for w in "${_STEAM_WINE_BINARIES[@]}"; do
			if [ "$base" = "$w" ]; then
				STEAM_PROC_REASON="wine-loader-binary"
				return 0
			fi
		done
	fi

	# 3. comm ends in .exe — on Linux that means a Windows binary hosted by Wine.
	#
	#    This tests COMM, never the executable's basename, and the distinction is
	#    not academic: every Claude agent's exe resolves to
	#    .../claude-code/bin/claude.exe. Keying this rule on the exe path would
	#    match all 14 agents. Their comm is "claude".
	case "$lcomm" in
		*.exe)
			STEAM_PROC_REASON="wine-hosted-exe-comm"
			return 0
			;;
	esac

	# 4. Named Wine service processes (wineserver carries no .exe suffix).
	for w in "${_STEAM_WINE_BINARIES[@]}"; do
		if [ "$lcomm" = "$w" ]; then
			STEAM_PROC_REASON="wine-service-comm"
			return 0
		fi
	done

	# 5. The kernel's own name for the process starts with "steam" (steam,
	#    steamwebhelper, and the 15-char truncation steam-runtime-l).
	case "$lcomm" in
		steam|steam[-_.]*|steamwebhelper*|steamerrorreport*)
			STEAM_PROC_REASON="steam-comm"
			return 0
			;;
	esac

	# 6. Backstop: an interpreter whose own executable is innocent, running a
	#    script that lives inside a Steam install — the Proton launcher (python3)
	#    and steam.sh (bash) are exactly this. Requires a Steam PATH in argv, not
	#    merely the word "steam", so an editor or grep naming this file is safe.
	if _steam_has_path_marker "$largv"; then
		STEAM_PROC_REASON="steam-path-in-argv"
		return 0
	fi

	return 1
}

# steam_proc_reason COMM EXE ARGV — print the rule that fired, or nothing.
# A tool that kills what it matches owes the user an explanation first.
steam_proc_reason() {
	steam_proc_match "$@" && printf '%s\n' "$STEAM_PROC_REASON"
}

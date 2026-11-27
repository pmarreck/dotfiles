# shellcheck shell=bash
# hook_init_cached NAME VAR: load into _hook_init_text the init script the
# startup engine cached for NAME (.pathconfig; lib/shell_startup/hook_init.lua),
# but only when this shell would run the very binary it describes: the same
# path, found by PATH search, with no function or alias of that name in the
# way. Returns 1 otherwise, and the caller runs the tool as before.
#
# The caller evaluates the text itself, where it used to evaluate the tool's
# output: evaluated in here, the scripts' `declare`s would become locals.
hook_init_cached() {
	local bin_var="SHELL_STARTUP_HOOK_${2}_BIN" init_var="SHELL_STARTUP_HOOK_${2}_INIT" dir found=''
	local -a dirs=()
	_hook_init_text=''
	[[ -n "${!bin_var-}" && -n "${!init_var-}" ]] || return 1
	declare -F "$1" >/dev/null && return 1
	alias "$1" >/dev/null 2>&1 && return 1
	# The engine searched exactly this PATH, so its answer stands; searching a
	# long PATH here would cost a millisecond or more per tool.
	if [[ "$PATH" == "${SHELL_STARTUP_HOOK_PATH-}" ]]; then
		found=${!bin_var}
	else
		# The first executable regular file named NAME in PATH order, as Bash
		# finds it to run NAME (these dotfiles turn command hashing off). An
		# empty entry is the current directory; read drops a trailing one.
		IFS=: read -r -a dirs <<<"$PATH"
		[[ "$PATH" != *: ]] || dirs+=('')
		for dir in "${dirs[@]}"; do
			[[ -n "$dir" ]] || dir=.
			if [[ -f "$dir/$1" && -x "$dir/$1" ]]; then found="$dir/$1"; break; fi
		done
	fi
	[[ -n "$found" && "$found" == "${!bin_var}" ]] || return 1
	# read stops at end of file with status 1; the text is what matters. A
	# file pruned since startup reads as empty and falls back.
	IFS= read -r -d '' _hook_init_text 2>/dev/null <"${!init_var}"
	[[ -n "$_hook_init_text" ]]
}

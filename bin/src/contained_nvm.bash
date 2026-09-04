# Load upstream nvm for one command while preserving this dotfiles repository's
# global `set -f` policy. nvm v0.40.6 uses unguarded globs during binary
# installation, so it must run with pathname expansion temporarily enabled.
_contained_nvm_restore_path() {
	local original_path="$1"
	local active_nvm_bin="${2-}"
	local entry
	local restored=''
	local -a entries=()

	IFS=: read -r -a entries <<<"$original_path"
	for entry in "${entries[@]}"; do
		case "$entry" in
			"$NVM_DIR"/versions/*/bin) continue ;;
		esac
		if [[ -n "$restored" ]]; then
			restored+=":$entry"
		else
			restored="$entry"
		fi
	done

	if [[ -n "$active_nvm_bin" ]]; then
		printf '%s:%s\n' "$active_nvm_bin" "$restored"
	else
		printf '%s\n' "$restored"
	fi
}

_contained_nvm_run() {
	local status=0
	local restore_noglob=false
	local real_home="$HOME"
	local real_path="$PATH"
	local nvm_home="$NVM_DIR/home"
	local system_bin="${NVM_SYSTEM_BIN-}"
	local active_nvm_bin=''

	if [[ "$-" == *f* ]]; then
		restore_noglob=true
		set +f
	fi

	export NPM_CONFIG_USERCONFIG="$NVM_DIR/npmrc"
	export npm_config_cache="$NVM_DIR/npm-cache"
	export COREPACK_HOME="$NVM_DIR/corepack"
	export NODE_REPL_HISTORY="$NVM_DIR/node_repl_history"

	# nvm hardcodes $HOME/.npmrc in its prefix compatibility check instead of
	# honoring NPM_CONFIG_USERCONFIG. Give it a private HOME so the caller's
	# existing npm configuration remains invisible and untouched.
	if command mkdir -p "$nvm_home"; then
		export HOME="$nvm_home"
		if [[ -z "$system_bin" && -d /run/current-system/sw/bin ]]; then
			system_bin=/run/current-system/sw/bin
		fi
		[[ -n "$system_bin" ]] && PATH="$system_bin:$PATH"

		# Sourcing nvm.sh replaces the public wrapper until this invocation ends.
		unset -f nvm
		if . "$NVM_DIR/nvm.sh" --no-use; then
			if nvm "$@"; then
				status=0
			else
				status=$?
			fi
		else
			status=$?
		fi
	else
		status=$?
	fi

	active_nvm_bin="${NVM_BIN-}"
	export HOME="$real_home"
	PATH="$(_contained_nvm_restore_path "$real_path" "$active_nvm_bin")"
	$restore_noglob && set -f

	# Reinstall the wrapper so every later invocation gets the same isolation.
	nvm() { _contained_nvm_run "$@"; }
	return "$status"
}

nvm() { _contained_nvm_run "$@"; }

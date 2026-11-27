# shellcheck source=destructive-audit.bash
. "${BASH_SOURCE[0]%/*}/destructive-audit.bash"

signal_identity() {
	local pid="$1" row=''
	local -a fields
	if [[ "$OSTYPE" == linux* ]]; then
		IFS= read -r -d '' row <"/proc/$pid/stat" 2>/dev/null || [[ -n "$row" ]] || return 1
		# The name is parenthesized and can itself contain whitespace or ')'.
		read -ra fields <<< "${row##*) }"
		[[ "${fields[19]:-}" =~ ^[0-9]+$ ]] || return 1
		printf '%s\n' "${fields[19]}"
	else
		LC_ALL=C ps -p "$pid" -o lstart= 2>/dev/null
	fi
}

# Send only to the snapshotted positive PIDs. Record the full batch before
# the first signal, since one of the targets may be the invoking shell.
signal_logged() {
	local operation="$1" signal="$2" echo_targets="$3" queue="$4"
	shift 4
	local journal pid before after row description status=1 failed=0 attempted=0 native='' candidate
	local -a pids=() identities=() names=()
	builtin kill -l "$signal" >/dev/null 2>&1 || [[ "$signal" == 0 ]] ||
		{ audit_error "$operation" "invalid signal: $signal"; return 2; }
	[[ $# -gt 0 ]] || return 1
	if [[ -n "$queue" ]]; then
		# util-linux supports queued signals to explicit PIDs.
		# Read every candidate, keeping the first native one: leaving early closed
		# the pipe under `type`, which reports a broken pipe if SIGPIPE is ignored.
		while IFS= read -r candidate; do
			if [[ -z "$native" && -x "$candidate" && ! "$candidate" -ef "${BASH_SOURCE[0]%/*}/../kill" ]]; then
				native="$candidate"
			fi
		done < <(type -a -p kill)
		[[ -n "$native" ]] ||
			{ audit_error "$operation" 'queued signals require a native kill executable'; return 2; }
	fi
	journal=$(audit_batch signals) || return 1
	printf 'command=%s signal=%q queue=%q\n' "$operation" "$signal" "$queue" > "$journal/log" || return 1
	for pid in "$@"; do
		[[ "$pid" =~ ^[1-9][0-9]*$ ]] || { audit_error "$operation" "invalid PID: $pid"; return 2; }
		before=$(signal_identity "$pid") || before=''
		row=$(LC_ALL=C ps -ww -p "$pid" -o ppid= -o pgid= -o uid= -o command= 2>/dev/null) || row=''
		after=$(signal_identity "$pid") || after=''
		if [[ -z "$before" || -z "$row" || "$before" != "$after" ]]; then
			printf 'skip pid=%s reason=process-unavailable-or-replaced\n' "$pid" >> "$journal/log" || return 1
			continue
		fi
		description=''
		if [[ "$echo_targets" == true ]]; then
			description=$(LC_ALL=C ps -p "$pid" -o comm= 2>/dev/null) || description=''
		fi
		printf 'target pid=%s started=%q ppid_pgid_uid_command=%q\n' "$pid" "$before" "$row" >> "$journal/log" || return 1
		pids+=("$pid"); identities+=("$before"); names+=("${description##*/}")
	done
	for (( attempted=0; attempted<${#pids[@]}; attempted++ )); do
		pid="${pids[attempted]}"
		after=$(signal_identity "$pid") || after=''
		if [[ "$after" != "${identities[attempted]}" ]]; then
			printf 'skip pid=%s reason=process-exited-or-replaced\n' "$pid" >> "$journal/log" || return 1
			failed=1
			continue
		fi
		if { if [[ -n "$queue" ]]; then "$native" --queue "$queue" -s "$signal" -- "$pid"; else builtin kill -s "$signal" -- "$pid"; fi; }; then
			printf 'result pid=%s status=sent\n' "$pid" >> "$journal/log" || return 1
			[[ "$echo_targets" == false ]] || printf '%s killed (pid %s)\n' "${names[attempted]}" "$pid"
			status=0
		else
			printf 'result pid=%s status=failed\n' "$pid" >> "$journal/log" || return 1
			failed=1
		fi
	done
	if [[ "$operation" == kill ]] && { [[ ${#pids[@]} -ne $# ]] || [[ "$failed" == 1 ]]; }; then return 1; fi
	return "$status"
}

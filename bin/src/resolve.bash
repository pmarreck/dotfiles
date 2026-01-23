resolve() {
	local unsafe=0 about=0 raw=0
	local -a pos=()

	_resolve_help() {
		cat <<'EOF'
Usage:
	resolve [--unsafe] [--raw] [-h|--help] [-a|--about] <cmd> [args...]

What it does:
	Recursively expands the first word through Bash alias chains, then replaces the
	final command with its absolute path (if it resolves to an external binary),
	and prints the fully resolved command line.

Safety modes:
	Default (SAFE):
		Alias bodies are tokenized by splitting on whitespace only.
		This NEVER executes code, but does NOT honor shell quoting or escapes.

	--unsafe:
		Uses eval to parse alias bodies exactly as Bash would (honors quoting),
		but MAY execute side effects if an alias contains command substitution,
		process substitution, redirects, etc. Use only if you trust your aliases.

Output modes:
	Default:
		Prints shell-escaped output (%q), safe for copy/paste.

	--raw:
		Prints unescaped output, joined by spaces, for readability.
		WARNING: If any argument contains spaces, tabs, or newlines, the output
		will be ambiguous and NOT safe to re-run without modification.

Options:
	-h, --help     Show this help.
	-a, --about    Print a one-line description.
	--unsafe       Use shell parsing (eval) for alias tokenization.
	--raw          Print unescaped output (may be ambiguous).

Examples:
	resolve l2
	resolve --unsafe l2
	resolve --raw l2
EOF
	}

	while (($#)); do
		case "$1" in
			-h|--help) _resolve_help; return 0 ;;
			-a|--about) about=1; shift; continue ;;
			--unsafe) unsafe=1; shift; continue ;;
			--raw) raw=1; shift; continue ;;
			--) shift; pos+=("$@"); break ;;
			-*) echo "resolve: unknown option: $1" >&2; _resolve_help >&2; return 2 ;;
			*) pos+=("$1"); shift; pos+=("$@"); break ;;
		esac
	done

	if ((about)); then
		echo "Resolve a command by recursively expanding Bash alias chains (first word only) and printing the fully flattened command invocation."
		return 0
	fi

	local cmd="${pos[0]:-}"
	if [[ -z "$cmd" ]]; then
		echo "resolve: missing <cmd>" >&2
		_resolve_help >&2
		return 2
	fi

	local -A seen=()
	local def rhs
	local -a argv repl
	argv=("${pos[@]}")

	while :; do
		cmd="${argv[0]}"
		def=$(alias "$cmd" 2>/dev/null) || break

		if [[ -n "${seen[$cmd]:-}" ]]; then
			echo "resolve: alias cycle detected at '$cmd'" >&2
			return 1
		fi
		seen["$cmd"]=1

		rhs=${def#*=}
		rhs=${rhs#\'}
		rhs=${rhs%\'}

		repl=()
		if ((unsafe)); then
			# UNSAFE: may execute side effects if rhs contains executable shell syntax.
			eval "repl=($rhs)"
		else
			# SAFE: whitespace split only.
			read -r -a repl <<<"$rhs"
		fi

		argv=("${repl[@]}" "${argv[@]:1}")
	done

	local path
	path=$(type -P -- "${argv[0]}" 2>/dev/null || true)
	[[ -n "$path" ]] && argv[0]="$path"

	if ((raw)); then
		local warn=0 arg
		for arg in "${argv[@]}"; do
			[[ "$arg" =~ [[:space:]] ]] && { warn=1; break; }
		done
		if ((warn)); then
			echo "resolve: warning: --raw output contains whitespace; result is ambiguous and not shell-safe" >&2
		fi
		printf '%s' "${argv[0]}"
		for arg in "${argv[@]:1}"; do
			printf ' %s' "$arg"
		done
		printf '\n'
	else
		printf '%q ' "${argv[@]}"
		printf '\n'
	fi
}

#!/usr/bin/env bash

randompassdict() {
	[ -n "${EDIT:-}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "${BASH_SOURCE[0]}" && return
	case "${1:-}" in
		-h | --help)
			if [ $# -ne 1 ]; then
				echo "Error: --help does not accept arguments." >&2
				return 2
			fi
			_randompassdict_help
			return 0
			;;
		--about)
			if [ $# -ne 1 ]; then
				echo "Error: --about does not accept arguments." >&2
				return 2
			fi
			printf 'randompassdict 1.0.0 - cryptographic dictionary-passphrase generator (%s/%s)\n' \
				"$(uname -s)" "$(uname -m)"
			return 0
			;;
	esac
	if [ $# -lt 1 ] || [ $# -gt 3 ]; then
		_randompassdict_help
		return 2
	fi
	local numwords=$1
	local minlen=${2:-4}
	local maxlen=${3:-14}
	if [[ ! "$numwords" =~ ^[1-9][0-9]*$ ]] ||
	   [[ ! "$minlen" =~ ^[1-9][0-9]*$ ]] ||
	   [[ ! "$maxlen" =~ ^[1-9][0-9]*$ ]] ||
	   (( minlen > maxlen )); then
		echo "Error: word count and lengths must be positive integers, and min-word-length must not exceed max-word-length." >&2
		return 2
	fi

	local dict
	dict=$(load_and_filter_dict "$minlen" "$maxlen") || return 1
	# Observable password values, rather than source-file lines, determine
	# entropy. Reject whitespace-bearing records because spaces delimit words,
	# and deduplicate while preserving first-seen dictionary order.
	dict=$(printf '%s\n' "$dict" |
		awk 'NF && $0 !~ /[[:space:]]/ && !seen[$0]++ { print }')
	if [[ -z "$dict" ]]; then
		echo "Error: dictionary contains no usable words in the requested length range." >&2
		return 1
	fi

	local poolsize
	poolsize=$(printf '%s\n' "$dict" | awk 'END { print NR }')
	if [[ -n "${JUST_OUTPUT_DICTIONARY:-}" ]]; then
		printf '%s\n' "$dict"
		return 0
	fi

	needs shuf || return 1
	if [[ ! -r /dev/urandom ]]; then
		echo "Error: cryptographic random source /dev/urandom is unavailable." >&2
		return 1
	fi
	local words
	words=$(
		set -o pipefail
		printf '%s\n' "$dict" |
			shuf --random-source=/dev/urandom -r -n "$numwords" |
			paste -sd ' ' -
	) || {
		echo "Error: cryptographically secure word selection failed." >&2
		return 1
	}
	printf '%s\n' "$words"

	local combinations combinations_with_thousands_sep entropy_bits
	combinations=$(calc "${poolsize}^${numwords}") || return 1
	combinations_with_thousands_sep=$(_randompassdict_group_integer "$combinations")
	entropy_bits=$(awk -v pool="$poolsize" -v count="$numwords" \
		'BEGIN { printf "%.3f", count * log(pool) / log(2) }')
	echo >&2
	note "$poolsize available words in the dictionary suit the requested length range [$minlen-$maxlen]."
	if [[ -n "${FILTERPROPERNOUNS:-}" ]]; then
		note "Capitalized words were excluded."
	fi
	note "$combinations_with_thousands_sep possible combinations ($entropy_bits bits of entropy); one-guess success odds are 1 in $combinations_with_thousands_sep."
}

_randompassdict_help() {
	cat <<'EOF'
Usage: randompassdict NUM_WORDS [MIN_WORD_LENGTH [MAX_WORD_LENGTH]]

Generate a space-delimited passphrase by uniformly sampling dictionary words
with replacement. The defaults are 4 and 14 characters. Selection reads
directly from /dev/urandom and fails closed if secure selection is unavailable.
Duplicate and whitespace-bearing dictionary entries do not add entropy.

Options:
	-h, --help  Show this help
	--about     Show version and platform information
EOF
}

# Format an exact non-negative integer without routing it through a machine
# integer or floating-point type, both of which corrupt sufficiently large
# combination counts.
_randompassdict_group_integer() {
	local digits="$1"
	local grouped=''
	local split
	while (( ${#digits} > 3 )); do
		grouped=",${digits: -3}${grouped}"
		split=$((${#digits} - 3))
		digits=${digits:0:split}
	done
	printf '%s%s\n' "$digits" "$grouped"
}

# Run the function if this script is executed directly
if ! (return 0 2>/dev/null); then
	# Check if we are running tests
	if [ "${1:-}" = "--test" ]; then
		# Execute the test file, silence stdout but show stderr (errors)
		"$HOME/dotfiles/bin/test/$(basename "${0##\-}")_test" >/dev/null
		exit $?
	else
		# If called directly, pass all arguments to the function
		$(basename "${0##\-}") "$@"
	fi
fi

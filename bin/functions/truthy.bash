# Define the truthy function; keep it POSIX-compatible
truthy() {
	# Check if EDIT is set and not empty, then unset and call edit_function
	if [ -n "$EDIT" ]; then
		unset EDIT
		edit_function "$0" "$0"
		return
	fi

	var_name="$1"

	# 1. Check if the variable exists; if not, return false immediately
	if ! eval "[ -n \"\${$var_name+set}\" ]"; then
		return 1
	fi

	# 2. Validate the variable name (POSIX regex emulation with `case`)
	case "$var_name" in
		[!a-zA-Z_]*|*[!a-zA-Z0-9_]*)
			echo "Error: '$var_name' is not a valid shell variable name" >&2
			return 2
			;;
	esac

	# 3. Retrieve the variable value (POSIX-compatible eval)
	value=$(eval "printf '%s\n' \"\$$var_name\"")

	# 4. Convert value to lowercase (manual loop, no `${var,,}`)
	lower_value=""
	for i in $(printf '%s' "$value" | fold -w1); do
		case "$i" in
			[A-Z]) lower_value="${lower_value}$(printf '\\%o' "$(( $(printf '%d' "'$i") + 32 ))")" ;;
			*) lower_value="${lower_value}${i}" ;;
		esac
	done

	# 5. Check if the value is "truthy"
	case "$lower_value" in
		1|t|true|on|y|yes|enable|enabled)
			return 0
			;;
		*)
			return 1
			;;
	esac
}
export -f truthy

# Define the falsey function in terms of the truthy function
falsey() {
	[ -n "${EDIT}" ] && unset EDIT && edit_function "$0" "$0" && return

	truthy "$1" && return 1 || return 0
}
export -f falsey

# tests
if [ "$RUN_DOTFILE_TESTS" == "true" ]; then
	source_relative_once assert.bash
	_a=1
	_b=true
	_d=0
	_e=false
	truthy _a
	assert "$?" == "0"
	truthy _b
	assert "$?" == "0"
	truthy _c
	assert "$?" == "1"
	truthy _d
	assert "$?" == "1"
	truthy _e
	assert "$?" == "1"
	falsey _a
	assert "$?" == "1"
	falsey _b
	assert "$?" == "1"
	falsey _c
	assert "$?" == "0"
	falsey _d
	assert "$?" == "0"
	falsey _e
	assert "$?" == "0"
	unset _a _b _c _d _e
fi

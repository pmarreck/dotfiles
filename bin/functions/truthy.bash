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

	# 4. Convert value to lowercase (manual loop, no `${var,,}`, due to desiring POSIX...)
	lower_value=""
	for i in $(printf '%s' "$value" | fold -w1); do
		case "$i" in
			[A-Z]) lower_value="${lower_value}$(printf "\\$(printf '%03o' "$(( $(printf '%d' "'$i") + 32 ))")")" ;;
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

if truthy DEBUG_SHELLCONFIG; then
	echo "Loaded truthy.bash"
fi

# tests
if truthy RUN_DOTFILE_TESTS; then
	source_relative_once $HOME/dotfiles/bin/functions/assert.bash
	source_relative_once $HOME/dotfiles/bin/functions/test_reporter.bash

	test_truthy() {
		# Set up test variables
		_a=1
		_b=true
		_c=yes
		_d=on
		_e=y
		_f=enable
		_g=enabled
		_h=TRUE
		_i=YES
		_A=0
		_B=false
		# _C # remains unset
		_D=no
		_E=off
		_F=disable
		_G=disabled
		_H=n
		_I=FALSE
		_J=NO

		# Run tests
		truthy _a
		assert "$?" == "0" "1 should have returned truthy"
		truthy _b
		assert "$?" == "0" "true should have returned truthy"
		truthy _c
		assert "$?" == "0" "yes should have returned truthy"
		truthy _d
		assert "$?" == "0" "on should have returned truthy"
		truthy _e
		assert "$?" == "0" "y should have returned truthy"
		truthy _f
		assert "$?" == "0" "enable should have returned truthy"
		truthy _g
		assert "$?" == "0" "enabled should have returned truthy"
		truthy _h
		assert "$?" == "0" "TRUE should have returned truthy"
		truthy _i
		assert "$?" == "0" "YES should have returned truthy"
		falsey _A
		assert "$?" == "0" "0 should have returned falsey"
		falsey _B
		assert "$?" == "0" "false should have returned falsey"
		falsey _C
		assert "$?" == "0" "an undefined variable should have returned falsey"
		truthy _C
		assert "$?" == "1" "an undefined variable should have NOT returned truthy"
		truthy _D
		assert "$?" == "1" "no should have NOT returned truthy"
		falsey _D
		assert "$?" == "0" "no should have returned falsey"
		truthy _E
		assert "$?" == "1" "off should have NOT returned truthy"
		falsey _F
		assert "$?" == "0" "disable should have returned falsey"
		falsey _G
		assert "$?" == "0" "disabled should have returned falsey"
		falsey _H
		assert "$?" == "0" "n should have returned falsey"
		falsey _I
		assert "$?" == "0" "FALSE should have returned falsey"
		falsey _J
		assert "$?" == "0" "NO should have returned falsey"
	}

	test_cleanup() {
		unset _a _b _c _d _e _f _g _A _B _D _E _F _G _H _I _J
	}

	run_test_suite "truthy" : test_truthy test_cleanup
fi

#!/usr/bin/env bash
set -euo pipefail

script_path=$(command -v "$0" 2>/dev/null || echo "$0")
script_dir=$(cd "$(dirname "$script_path")" 2>/dev/null && pwd -P)
script_name=$(basename "$script_path")
readonly BACKUP_ROOT="/tmp/rstt$$"

usage() {
	cat <<USAGE
Usage: $script_name [options] file1 [file2 ...]

Convert consistent leading spaces in files to tabs.

OPTIONS:
	-h, --help      Show this help information
	--test          Run the test suite (silent on success)
	-i, --in-place  Modify files in place instead of writing to stdout
USAGE
}

require_awk() {
	local bin
	if command -v gawk >/dev/null 2>&1; then
		bin=$(command -v gawk)
	elif command -v awk >/dev/null 2>&1; then
		bin=$(command -v awk)
	else
		echo "Error: gawk or awk is required" >&2
		return 1
	fi
	printf '%s' "$bin"
}

AWK_BIN=$(require_awk)
readonly AWK_BIN

resolve_backup_path() {
	local file="$1"
	local base
	base=$(basename "$file")
	local candidate="$BACKUP_ROOT/${base}.maybe-no-tabs"
	local suffix=1
	while [ -e "$candidate" ]; do
		candidate="$BACKUP_ROOT/${base}.maybe-no-tabs.$suffix"
		suffix=$((suffix + 1))
	done
	printf '%s' "$candidate"
}
determine_tab_size_in_spaces() {
	local file="$1"
	"$AWK_BIN" '
	{
		if (length($0) > 0 && ($0 ~ /^ / || $0 ~ /^\t/)) {
			match($0, /^ */);
			if (RLENGTH > 0) {
				space_indents[RLENGTH]++;
			}
			match($0, /^\t*/);
			if (RLENGTH > 0) {
				tab_indents[RLENGTH]++;
			}
		}
	}
	END {
		for (indent in space_indents) {
			if (indent > 0 && space_indents[indent] > max_space_count) {
				third_space = second_space;
				second_space = max_space;
				max_space = indent;
				max_space_count = space_indents[indent];
			}
		}
		for (indent in tab_indents) {
			if (indent > 0 && tab_indents[indent] > max_tab_count) {
				third_tab = second_tab;
				second_tab = max_tab;
				max_tab = indent;
				max_tab_count = tab_indents[indent];
			}
		}
		if (max_tab_count > max_space_count) {
			print 0;
			exit;
		}
		if (max_space == 0) {
			print 0;
			exit;
		}
		div_count = split("8 7 6 5 4 3 2", divs, " ");
		for (i = 1; i <= div_count; i++) {
			d = divs[i];
			if (max_space % d == 0 &&
				(second_space == 0 || second_space % d == 0) &&
				(third_space == 0 || third_space % d == 0)) {
				print d;
				exit;
			}
		}
		print 1;
	}
	' "$file"
}
process_file() {
	local file="$1"
	local in_place="$2"

	if ! file -b --mime-type "$file" | grep -q '^text/'; then
		echo "Warning: Not a text file: $file" >&2
		return 1
	fi

	local indent
	indent=$(determine_tab_size_in_spaces "$file")

	if [ "${indent:-0}" -le 0 ]; then
		if [ "$in_place" = true ]; then
			echo "No changes needed for: $file" >&2
		else
			cat "$file"
		fi
		return 0
	fi

	local indent_spaces
	printf -v indent_spaces '%*s' "$indent" ''

	if [ "$in_place" = true ]; then
		mkdir -p "$BACKUP_ROOT"
		local backup_file
		backup_file=$(resolve_backup_path "$file")
		mkdir -p "$(dirname "$backup_file")"
		cp -p "$file" "$backup_file"
		printf 'Backup stored for %s at %s\n' "$file" "$backup_file" >&2

		local stat_bin stat_fmt
		if command -v gstat >/dev/null 2>&1; then
			stat_bin=$(command -v gstat)
			stat_fmt='-c %a'
		else
			stat_bin=$(command -v stat)
			stat_fmt='-f %A'
		fi
		local perms
		perms=$($stat_bin $stat_fmt "$file")

		"$AWK_BIN" -v indent="$indent_spaces" '
		{
			while (match($0, "^\t*" indent)) {
				$0 = gensub("^(\t*)" indent, "\\1\t", "g");
			}
			print;
		}
		' "$file" >"$file.new"

		chmod "$perms" "$file.new"
		mv "$file.new" "$file"
		echo "Reformatted: $file (indent size: $indent)"
	else
		"$AWK_BIN" -v indent="$indent_spaces" '
		{
			while (match($0, "^\t*" indent)) {
				$0 = gensub("^(\t*)" indent, "\\1\t", "g");
			}
			print;
		}
		' "$file"
	fi
}
run_tests() {
	local test_script="$script_dir/test/${script_name}_test"
	if [ ! -x "$test_script" ]; then
		echo "Test script not found: $test_script" >&2
		return 1
	fi
	RSTT_RUNNING_SUITE=1 "$test_script" >/dev/null
}

reformat_spaces_to_tabs() {
	local in_place=false
	local files=()

	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)
				usage
				return 0
				;;
			--test)
				if [ $# -ne 1 ]; then
					echo "Error: --test does not accept additional arguments" >&2
					return 1
				fi
				run_tests
				return $?
				;;
			-i|--in-place)
				in_place=true
				shift
				continue
				;;
			--)
				shift
				files+=("$@")
				break
				;;
			-*)
				echo "Error: Unknown option $1" >&2
				usage >&2
				return 1
				;;
			*)
				files+=("$1")
				;;
		esac
		shift || true
	done

	if [ ${#files[@]} -eq 0 ]; then
		echo "Usage: $script_name [options] file1 [file2 ...]" >&2
		return 1
	fi

	local file
	for file in "${files[@]}"; do
		if [ ! -f "$file" ]; then
			echo "Warning: File not found: $file" >&2
			continue
		fi
		process_file "$file" "$in_place"
	done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	reformat_spaces_to_tabs "$@"
fi

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
	local base="${file##*/}"
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
	# shellcheck disable=SC2016 # This is an Awk program, not shell interpolation.
	"$AWK_BIN" '
	function ranks_before(left, right) {
		if (right == 0) {
			return 1;
		}
		if (space_indents[left] != space_indents[right]) {
			return space_indents[left] > space_indents[right];
		}
		return (left + 0) < (right + 0);
	}
	function rank_width(width, position, displaced) {
		for (position = 1; position <= 3; position++) {
			if (ranks_before(width, ranked_widths[position])) {
				displaced = ranked_widths[position];
				ranked_widths[position] = width;
				width = displaced;
				if (width == 0) {
					return;
				}
			}
		}
	}
	{
		if ($0 ~ /^[ \t]*\r?$/) {
			next;
		}
		match($0, /^\t*/);
		tab_count = RLENGTH;
		if (tab_count > 0) {
			tabbed_lines++;
		}
		remaining = substr($0, tab_count + 1);
		match(remaining, /^ */);
		space_count = RLENGTH;
		if (space_count > 0) {
			spaced_lines++;
			space_indents[space_count]++;
		}
	}
	END {
		for (indent in space_indents) {
			rank_width(indent);
		}
		if (tabbed_lines > spaced_lines) {
			print 0;
			exit;
		}
		if (ranked_widths[1] == 0) {
			print 0;
			exit;
		}
		div_count = split("8 7 6 5 4 3 2", divs, " ");
		for (i = 1; i <= div_count; i++) {
			d = divs[i];
			divides_all = 1;
			for (position = 1; position <= 3; position++) {
				width = ranked_widths[position];
				if (width != 0 && width % d != 0) {
					divides_all = 0;
					break;
				}
			}
			if (divides_all) {
				print d;
				exit;
			}
		}
		print 0;
	}
	' "$file"
}

is_text_file() {
	local file="$1"
	if [ ! -s "$file" ]; then
		return 0
	fi

	local mime_type
	mime_type=$(file -b --mime-type -- "$file") || return 1
	case "$mime_type" in
		text/*|application/json|application/xml|application/*+json|application/*+xml)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

process_file() {
	local file="$1"
	local in_place="$2"
	local filesystem_path="$file"
	if [[ "$filesystem_path" == -* ]]; then
		filesystem_path="./$filesystem_path"
	fi

	if ! is_text_file "$filesystem_path"; then
		echo "Warning: Not a text file: $file" >&2
		return 1
	fi

	local indent
	indent=$(determine_tab_size_in_spaces "$filesystem_path")

	if [ "${indent:-0}" -le 0 ]; then
		if [ "$in_place" = true ]; then
			echo "No changes needed for: $file" >&2
		else
			cat "$filesystem_path"
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
		cp -p "$filesystem_path" "$backup_file"
		printf 'Backup stored for %s at %s\n' "$file" "$backup_file" >&2

		local stat_bin
		local -a stat_args
		if command -v gstat >/dev/null 2>&1; then
			stat_bin=$(command -v gstat)
			stat_args=(-c '%a')
		else
			stat_bin=$(command -v stat)
			if "$stat_bin" --version 2>/dev/null | grep -q 'GNU coreutils'; then
				stat_args=(-c '%a')
			else
				stat_args=(-f '%Lp')
			fi
		fi
		local perms
		perms=$("$stat_bin" "${stat_args[@]}" "$filesystem_path")

		local replacement_template="${filesystem_path}.tmp.XXXXXX"
		if [[ "$replacement_template" == -* ]]; then
			replacement_template="./$replacement_template"
		fi
		local replacement_path
		replacement_path=$(mktemp "$replacement_template")
		if ! cp -p "$filesystem_path" "$replacement_path"; then
			unlink "$replacement_path"
			return 1
		fi

		# shellcheck disable=SC2016 # This is an Awk program.
		if ! "$AWK_BIN" -v indent="$indent_spaces" '
		{
			if ($0 !~ /^[ \t]*\r?$/) {
				while (match($0, "^\t*" indent)) {
					$0 = gensub("^(\t*)" indent, "\\1\t", "g");
				}
			}
			print;
		}
		' "$filesystem_path" >"$replacement_path"; then
			unlink "$replacement_path"
			return 1
		fi

		chmod "$perms" "$replacement_path"
		mv "$replacement_path" "$filesystem_path"
		echo "Reformatted: $file (indent size: $indent)"
	else
		# shellcheck disable=SC2016 # This is an Awk program.
		"$AWK_BIN" -v indent="$indent_spaces" '
		{
			if ($0 !~ /^[ \t]*\r?$/) {
				while (match($0, "^\t*" indent)) {
					$0 = gensub("^(\t*)" indent, "\\1\t", "g");
				}
			}
			print;
		}
		' "$filesystem_path"
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

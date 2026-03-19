# Glob compgen -G Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ~800 lines of manual glob expansion logic (fd/find fallbacks, space-handling, duplicated shopt blocks) with bash's `compgen -G` builtin, fix the dotfile warning false positive, and add extglob support.

**Architecture:** `compgen -G "$pattern"` replaces all manual expansion paths. Brace expansion preprocessor and output/execution logic are preserved unchanged. A `_restore_shopts` helper DRYs up the ~6 duplicated restore blocks.

**Tech Stack:** Bash, `compgen -G` builtin

**Spec:** `docs/superpowers/specs/2026-03-19-glob-compgen-refactor-design.md`

**Note:** Line numbers throughout this plan refer to the **original unmodified file**. Since tasks modify the same files sequentially, implementers should search for surrounding context strings rather than relying on absolute line numbers after Task 1.

---

### Task 1: Add Failing Tests for New Behavior

**Files:**
- Modify: `bin/test/glob_test`

- [ ] **Step 1: Add extglob test**

Add after Test 56 (the command-detection test, before the `popd`):

```bash
  # Test 58: Extglob pattern matching with @(...)
  (( tests++ ))
  touch foo.jpg bar.png baz.gif
  output=$(glob "@(*.jpg|*.png)" 2>/dev/null)
  expected_files=$'bar.png\nfoo.jpg'
  assert "$output" == "$expected_files" "glob should handle extglob @(...) patterns"
  (( fails += $? ))
  rm -f foo.jpg bar.png baz.gif
```

- [ ] **Step 2: Add dotfile false-positive test**

Add after the extglob test:

```bash
  # Test 59: Dotfile warning should NOT fire when no dotfiles match the full pattern
  (( tests++ ))
  touch "My Book (Z-Library).pdf" .hidden_file
  warning=$(glob "* (Z-Library).*" 2>&1 >/dev/null)
  assert "$warning" == "" "glob should not warn about dotfiles when no dotfiles match the full pattern"
  (( fails += $? ))
  rm -f "My Book (Z-Library).pdf" .hidden_file
```

- [ ] **Step 3: Run tests to verify both new tests fail**

Run: `bash bin/test/glob_test 2>&1`
Expected: Test 57 fails (extglob not supported), Test 58 fails (dotfile warning fires incorrectly). Pre-existing tests 20-22 also fail (case-insensitive FS issue — separate fix).

- [ ] **Step 4: Commit failing tests**

```bash
git add bin/test/glob_test
git commit -m "Add failing tests for extglob support and dotfile warning false positive"
```

---

### Task 2: Fix Case-Insensitive Test Failures (Independent)

**Files:**
- Modify: `bin/test/glob_test`

- [ ] **Step 1: Add filesystem case-sensitivity probe**

Add a helper function after `glob_path=$(command -v glob)` (line 11), before the `pushd`:

```bash
  # Detect filesystem case-sensitivity at runtime
  local _cs_probe
  _cs_probe=$(mktemp --tmpdir case_probe.XXXXXX)
  local case_insensitive_fs=false
  if [[ -e "${_cs_probe^^}" && "${_cs_probe}" != "${_cs_probe^^}" ]]; then
    case_insensitive_fs=true
  fi
  rm -f "$_cs_probe"
```

- [ ] **Step 2: Fork case-insensitive tests based on detected FS**

Replace Test 19 setup (lines 239-247) and Tests 20-22 (lines 249-274) with filesystem-aware versions:

```bash
  # Test 19: Case-insensitive matching with --ignore-case
  (( tests++ ))
  if $case_insensitive_fs; then
    # On case-insensitive FS, files that differ only in case collapse
    # Use filenames that differ in MORE than just case
    touch "alpha.JPG" "beta.Jpg" "other.png" "test with spaces.jpg" "test1.jpg" "test2.jpg"

    # Test without ignore-case (case-sensitive pattern "test*.jpg")
    output=$(glob "test*.jpg" 2>/dev/null)
    expected_files=$'test with spaces.jpg\ntest1.jpg\ntest2.jpg'
    assert "$output" == "$expected_files" "glob should be case-sensitive by default"
    (( fails += $? ))

    # Test with --ignore-case using UPPERCASE pattern to prove case folding works
    (( tests++ ))
    output=$(glob --ignore-case "TEST*.JPG" 2>/dev/null)
    expected_files=$'test with spaces.jpg\ntest1.jpg\ntest2.jpg'
    assert "$output" == "$expected_files" "glob should match case-insensitively with --ignore-case (case-insensitive FS)"
    (( fails += $? ))

    # Test with -i shorthand using UPPERCASE pattern
    (( tests++ ))
    output=$(glob -i "TEST*.JPG" 2>/dev/null)
    expected_files=$'test with spaces.jpg\ntest1.jpg\ntest2.jpg'
    assert "$output" == "$expected_files" "glob should match case-insensitively with -i shorthand (case-insensitive FS)"
    (( fails += $? ))

    # Test -i with command execution — should find all *.jpg case-insensitively
    (( tests++ ))
    output=$(glob -i printf '%s\n' "*.jpg" 2>/dev/null)
    output=$(printf '%s\n' "$output" | LC_ALL=C sort)
    expected_files=$'alpha.JPG\nbeta.Jpg\ntest with spaces.jpg\ntest1.jpg\ntest2.jpg'
    expected_files=$(printf '%s\n' "$expected_files" | LC_ALL=C sort)
    assert "$output" == "$expected_files" "glob should execute commands with case-insensitive matching (case-insensitive FS)"
    (( fails += $? ))

    rm -f "alpha.JPG" "beta.Jpg" "other.png" "test with spaces.jpg" "test1.jpg" "test2.jpg"
  else
    # On case-sensitive FS, original tests work fine
    touch "Test.JPG" "test.Jpg" "TEST.jpg" "other.png" "test with spaces.jpg" "test1.jpg" "test2.jpg"

    output=$(glob "test*.jpg" 2>/dev/null)
    expected_files=$'test with spaces.jpg\ntest1.jpg\ntest2.jpg'
    assert "$output" == "$expected_files" "glob should be case-sensitive by default"
    (( fails += $? ))

    (( tests++ ))
    output=$(glob --ignore-case "test*.jpg" 2>/dev/null)
    expected_files=$'TEST.jpg\nTest.JPG\ntest with spaces.jpg\ntest.Jpg\ntest1.jpg\ntest2.jpg'
    assert "$output" == "$expected_files" "glob should match case-insensitively with --ignore-case"
    (( fails += $? ))

    (( tests++ ))
    output=$(glob -i "test*.jpg" 2>/dev/null)
    expected_files=$'TEST.jpg\nTest.JPG\ntest with spaces.jpg\ntest.Jpg\ntest1.jpg\ntest2.jpg'
    assert "$output" == "$expected_files" "glob should match case-insensitively with -i shorthand"
    (( fails += $? ))

    (( tests++ ))
    output=$(glob -i printf '%s\n' "test*.jpg" 2>/dev/null)
    output=$(printf '%s\n' "$output" | LC_ALL=C sort)
    expected_files=$'TEST.jpg\nTest.JPG\ntest with spaces.jpg\ntest.Jpg\ntest1.jpg\ntest2.jpg'
    expected_files=$(printf '%s\n' "$expected_files" | LC_ALL=C sort)
    assert "$output" == "$expected_files" "glob should execute commands with case-insensitive matching"
    (( fails += $? ))

    rm -f "Test.JPG" "test.Jpg" "TEST.jpg" "other.png" "test with spaces.jpg" "test1.jpg" "test2.jpg"
  fi
```

- [ ] **Step 3: Run tests to verify case-insensitive tests now pass**

Run: `bash bin/test/glob_test 2>&1`
Expected: Tests 19-22 now pass. Tests 57-58 still fail (not yet implemented).

- [ ] **Step 4: Commit**

```bash
git add bin/test/glob_test
git commit -m "Fix case-insensitive glob tests: detect FS case-sensitivity at runtime"
```

---

### Task 3: Refactor the Expansion Engine

This is the core refactor. Replace ~800 lines of manual expansion logic with `compgen -G`.

**Files:**
- Modify: `bin/glob`

- [ ] **Step 1: Add `_restore_shopts` helper and expanded shopt save/restore**

Replace the shopt save block (lines 250-268) and add a restore helper. After line 248 (`debug "Final arguments after brace expansion: $*"`), replace through line 268 with:

```bash
	# Store original globbing states to restore later
	local glob_disabled=false nullglob_set dotglob_set nocaseglob_set extglob_set globstar_set

	[[ $- == *f* ]] && glob_disabled=true && debug "Globbing is disabled (noglob is set)"

	shopt -q nullglob && nullglob_set=true || nullglob_set=false
	shopt -q dotglob && dotglob_set=true || dotglob_set=false
	shopt -q nocaseglob && nocaseglob_set=true || nocaseglob_set=false
	shopt -q extglob && extglob_set=true || extglob_set=false
	shopt -q globstar && globstar_set=true || globstar_set=false

	local dotglob_effective=$dotglob_set
	local dotglob_forced=false
	if $include_dotfiles; then
		dotglob_effective=true
	fi

	# Centralized restore function — called on every exit path
	_restore_shopts() {
		$glob_disabled && set -f
		$dotglob_forced && shopt -u dotglob
		$extglob_set || shopt -u extglob
		$globstar_set || shopt -u globstar
		if $ignore_case; then
			if $nocaseglob_set; then
				shopt -s nocaseglob
			else
				shopt -u nocaseglob
			fi
		fi
	}
```

- [ ] **Step 2: Delete fd/find infrastructure**

Delete lines 270-286 entirely (the `finder_cmd`, `finder_kind`, `finder_warned` variables and `_warn_find_fallback` function). These are no longer needed.

- [ ] **Step 3: Update the globbing-enable section**

Replace lines 603-615 with:

```bash
	# Enable globbing features
	set +f           # Enable globbing
	shopt -s extglob globstar
	if $include_dotfiles && ! $dotglob_set; then
		shopt -s dotglob
		dotglob_forced=true
	fi
	if $ignore_case; then
		debug "Enabling case-insensitive globbing"
		shopt -s nocaseglob
	fi
```

- [ ] **Step 4: Replace all early-return restore blocks with `_restore_shopts`**

Note: `_restore_shopts` is defined inside `glob()` but bash makes inner functions global. Add `unset -f _restore_shopts` before every `return` statement in `glob` to prevent leaking the function into the caller's session. The pattern becomes: `_restore_shopts; unset -f _restore_shopts; return N`.

Replace every duplicated restore block (in the `--double-quote` error, `--dry-run` error, `--batch` error, ARG_MAX error, no-matches return, and end-of-function restore sections) with a single call to `_restore_shopts`. There are approximately 6 such blocks. Each block that looks like:

```bash
		if $glob_disabled; then set -f; fi
		if $dotglob_forced; then
			shopt -u dotglob
		fi
		if $ignore_case; then
			if $nocaseglob_set; then
				shopt -s nocaseglob
			else
				shopt -u nocaseglob
			fi
		fi
```

becomes:

```bash
		_restore_shopts
		unset -f _restore_shopts
```

- [ ] **Step 5: Replace the expansion loop (lines 708-1082) with compgen -G**

Replace the entire block from `local processed_args=()` through the closing `done` of the `for arg in "${args[@]}"` loop with:

```bash
	local processed_args=()
	local _glob_patterns_seen=()  # track glob patterns for dotfile warning
	for arg in "${args[@]}"; do
		# If we have a command and arg starts with - or --, pass it through
		if [[ -n "$exec_command" && ("$arg" == -* || "$arg" == --*) ]]; then
			debug "Passing through option: $arg"
			processed_args+=("$arg")
		# Check if arg is a glob pattern (standard metacharacters or extglob prefixes)
		elif [[ "$arg" == *[\*\?\[]* || "$arg" =~ [?*+@!]\( ]]; then
			debug "Processing glob pattern: $arg"
			_glob_patterns_seen+=("$arg")

			# Use compgen -G for expansion — handles spaces, **, extglob natively
			local matches=()
			mapfile -t matches < <(compgen -G "$arg")

			if [[ ${#matches[@]} -eq 0 ]]; then
				debug "No matches found for pattern: $arg - skipping"
			else
				debug "Found ${#matches[@]} matches for pattern: $arg"
				found_any_matches=true
				processed_args+=("${matches[@]}")
			fi
		else
			# Not a glob pattern, add as is
			debug "Adding non-glob argument: $arg"
			found_any_matches=true
			processed_args+=("$arg")
		fi
	done
```

- [ ] **Step 6: Replace the dotfile warning (lines 1084-1118) with compgen -G based version**

Replace the entire dotfile warning block with:

```bash
	# Warn about excluded dotfiles (only when dotglob was NOT enabled)
	if ! $dotglob_effective && [[ ${#_glob_patterns_seen[@]} -gt 0 ]]; then
		local _dotfile_warning_needed=false
		local _pattern
		for _pattern in "${_glob_patterns_seen[@]}"; do
			# Skip patterns that explicitly target dotfiles (start with . after any path prefix)
			local _basename="${_pattern##*/}"
			if [[ "$_basename" == .* ]]; then
				continue
			fi
			# Check if enabling dotglob would yield additional dotfile matches
			shopt -s dotglob
			local _dot_matches=()
			mapfile -t _dot_matches < <(compgen -G "$_pattern")
			shopt -u dotglob
			local _m
			for _m in "${_dot_matches[@]}"; do
				local _mbase="${_m##*/}"
				if [[ "$_mbase" == .* ]]; then
					_dotfile_warning_needed=true
					break 2
				fi
			done
		done
		if $_dotfile_warning_needed; then
			printf '\033[33mNote: dotfiles were excluded. Use --dotglob or --all to include them.\033[0m\n' >&2
		fi
	fi
```

- [ ] **Step 7: Remove the nullglob filter in command mode**

In the command execution section (around line 1146-1156 in the original), the nullglob filter loop is no longer needed since `compgen -G` already returns only real matches. Replace:

```bash
			local cmd_args=()
			local item
			for item in "${processed_args[@]}"; do
				# Special handling for nullglob in command mode
				# Skip any non-matching patterns that might have slipped through
				if $nullglob_set && [[ "$item" == *[*?[]* ]] && [[ ! -e "$item" ]]; then
					debug "Skipping non-matching pattern in command mode with nullglob: $item"
					continue
				fi
				cmd_args+=("$item")
			done
```

with simply:

```bash
			local cmd_args=("${processed_args[@]}")
```

- [ ] **Step 8: Run all tests**

Run: `bash bin/test/glob_test 2>&1`
Expected: ALL tests pass, including the new extglob test (57) and dotfile warning test (58).

- [ ] **Step 9: Commit**

```bash
git add bin/glob
git commit -m "Refactor glob: replace manual expansion engine with compgen -G

Remove ~800 lines of fd/find fallback logic, space-handling paths,
and duplicated shopt save/restore blocks. compgen -G handles spaces,
globstar, extglob, and nocaseglob natively.

Fixes: dotfile warning false positive (was word-splitting on spaces)
Adds: extglob pattern support (@, *, +, ?, ! prefixed groups)
Removes: eval calls in find fallback (security improvement)"
```

---

### Task 4: Update Help Text

**Files:**
- Modify: `bin/glob`

- [ ] **Step 1: Add EXTGLOB PATTERNS section to help text**

In `_show_help`, after the BRACE EXPANSION section (around line 92), add:

```
	EXTGLOB PATTERNS:
	Extended globbing patterns for advanced matching:

	@(pattern1|pattern2)    Match exactly one of the patterns
	*(pattern1|pattern2)    Match zero or more of the patterns
	+(pattern1|pattern2)    Match one or more of the patterns
	?(pattern1|pattern2)    Match zero or one of the patterns
	!(pattern1|pattern2)    Match anything except the patterns

	glob "@(*.jpg|*.png)"          # Match jpg or png files
	glob "!(*.bak|*.tmp)"         # Match everything except .bak and .tmp
```

- [ ] **Step 2: Remove fd/fdfind install advice and traversal mention**

Remove lines 108-122 from help text (the "When globbing requires filesystem traversal..." paragraph and the "FD INSTALL" section). Replace the traversal mention with:

```
	All pattern matching uses bash's built-in globbing engine via compgen -G.
	Recursive patterns (**) require bash 4.0+ with globstar support.
```

- [ ] **Step 3: Run tests to verify nothing broke**

Run: `bash bin/test/glob_test 2>&1`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add bin/glob
git commit -m "Update glob help text: add extglob docs, remove fd/find references"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Run the full test suite**

Run: `bash bin/test/glob_test 2>&1`
Expected: All tests pass (0 failures).

- [ ] **Step 2: Verify the user's exact reproduction case**

Run: `bash bin/glob --help | head -5` to confirm help works.
Run: `wc -l bin/glob` to confirm significant line reduction (target: ~500 lines, down from ~1315).

- [ ] **Step 3: Test remove_z_library_attrib still works**

Run: `bash bin/test/remove_z_library_attrib_test 2>&1`
Expected: All 3 tests pass.

- [ ] **Step 4: Verify the dotfile warning fix manually**

If in a directory with dotfiles and files matching a space-containing pattern that doesn't match dotfiles, confirm no spurious warning:

```bash
cd /tmp && touch .hidden "My Book (Test).pdf" && glob "* (Test).*" 2>&1 && rm .hidden "My Book (Test).pdf"
```

Expected: Shows `My Book (Test).pdf` with NO dotfile warning.

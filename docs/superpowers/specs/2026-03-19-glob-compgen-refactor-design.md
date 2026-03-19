# Glob Refactor: Replace Manual Expansion with `compgen -G`

**Date:** 2026-03-19
**Status:** Approved

## Problem

`bin/glob` was designed as a thin wrapper to temporarily enable bash globbing in a `set -f` environment. Over time it grew to ~1300 lines by reimplementing glob features manually — fd/find fallbacks for recursive patterns, custom space-handling paths, duplicated shopt save/restore blocks. This creates maintenance burden and bugs:

1. **Dotfile warning false positive**: Warns about excluded dotfiles even when no additional dotfiles would match the pattern. Root cause: the warning logic re-expands patterns via `files=($pattern)` which word-splits on spaces, causing incorrect matches.
2. **No extglob support**: Glob detection (`*[\*\?\[]*`) doesn't recognize extglob syntax like `@(a|b)`, so extglob patterns are treated as literals.
3. **~800 lines of duplicated logic**: Manual glob expansion via fd/find that bash can handle natively.

## Solution

Replace the manual expansion engine with `compgen -G`, a bash builtin that performs glob expansion on a single argument without word splitting. This handles spaces in patterns, `**` recursion (with globstar), extglob, dotglob, and nocaseglob — all natively.

## Architecture

```
Input args
  -> Parse flags (unchanged)
  -> Brace expansion preprocessing (unchanged)
  -> For each pattern:
      - If glob pattern (*, ?, [, or extglob @(, *(, +(, ?(, !():
          compgen -G "$pattern"
      - Else: pass through as literal
  -> Dotfile warning (fixed)
  -> Output formatting / command execution (unchanged)
```

## What Changes

### Deleted (~800 lines)
- All fd/find fallback logic for recursive patterns and patterns with spaces
- All manual space-handling paths (absolute path detection, cd-based expansion, fd/fdfind invocations)
- All duplicated nullglob/nocaseglob save/restore blocks scattered through the expansion logic
- The `_warn_find_fallback` function and `finder_cmd`/`finder_kind` variables
- fd/fdfind install advice from help text (no longer relevant)

### Simplified
- Glob detection regex expands to recognize extglob syntax:
  ```bash
  [[ "$arg" == *[\*\?\[]* || "$arg" =~ [?*+@!]\( ]]
  ```
  This catches standard glob metacharacters (`*`, `?`, `[`) and extglob prefixes (`@(`, `*(`, `+(`, `?(`, `!(`).
- The entire pattern expansion loop reduces to: `compgen -G "$pattern"` with appropriate shopts

### Fixed: Dotfile Warning
Current (broken): re-expands pattern via `_dot_matches=($_pattern)` which word-splits on spaces.

New approach (single traversal optimization):
```bash
# Run compgen -G once WITH dotglob enabled
shopt -s dotglob
mapfile -t all_matches < <(compgen -G "$pattern")
shopt -u dotglob  # (or restore to previous state)

# Partition into dot and non-dot sets
local dot_matches=() nondot_matches=()
for m in "${all_matches[@]}"; do
    local base="${m##*/}"
    if [[ "$base" == .* ]]; then
        dot_matches+=("$m")
    else
        nondot_matches+=("$m")
    fi
done

# If user didn't request dotglob, use nondot_matches as results
# and warn if dot_matches is non-empty
if (( ${#dot_matches[@]} > 0 )); then
    # warn
fi
```
This avoids traversing the filesystem twice.

### Shopt Management
All shopts that `glob` enables must be saved before and restored after. The current code saves/restores `nullglob`, `dotglob`, and `nocaseglob`. The refactor adds `extglob` and `globstar` to this list:

```bash
# Save
shopt -q extglob && extglob_set=true || extglob_set=false
shopt -q globstar && globstar_set=true || globstar_set=false

# Enable
shopt -s extglob globstar

# Restore (on every exit path)
$extglob_set || shopt -u extglob
$globstar_set || shopt -u globstar
```

### Added
- `shopt -s extglob globstar` with proper save/restore
- Extglob pattern detection in the glob-detection check
- Help text: `EXTGLOB PATTERNS` section documenting `@(a|b)`, `*(a|b)`, `+(a|b)`, `?(a|b)`, `!(a|b)`

### Unchanged
- Flag parsing and validation
- Brace expansion preprocessor (lines 212-243)
- Output formatting (`-0`, `-n`, `--double-quote`, default newline)
- Command mode, batch mode, dry-run, ARG_MAX checking
- The `--test` entry point

### Ordering Note
`compgen -G` returns results in filesystem order (same as `ls` without flags). In display mode, results are already sorted via `LC_ALL=C sort` — no change. In command mode, the current code preserves "natural glob order" from `files=($pattern)`. After the refactor, command mode gets `compgen -G` order, which is the same natural filesystem order. No behavioral change expected.

## Separate Fix: Case-Insensitive Test Failures

3 pre-existing test failures (tests 20, 21, 22) caused by macOS case-insensitive filesystem where `touch "Test.JPG" "test.Jpg" "TEST.jpg"` creates one file, not three.

Fix: detect filesystem case-sensitivity at runtime in the test, not via `uname` (macOS can be formatted case-sensitive). Probe the actual temp directory:

```bash
local _cs_probe
_cs_probe=$(mktemp --tmpdir case_probe.XXXXXX)
if [[ -e "${_cs_probe^^}" && "${_cs_probe}" != "${_cs_probe^^}" ]]; then
    case_insensitive=true
else
    case_insensitive=false
fi
rm -f "$_cs_probe"
```

Then fork the case-insensitive test expectations:
- **Case-sensitive FS**: expect all 6 files created separately, 6 matches
- **Case-insensitive FS**: filenames that differ only in case collapse to one file; adjust expected match count and filenames accordingly

This keeps the tests accurate on both Linux (case-sensitive) and macOS (either).

## Risk Assessment

- 54 passing tests cover all features and will catch regressions
- `compgen -G` is a bash builtin — no new dependencies
- Brace expansion preprocessing is preserved unchanged
- All external interfaces (flags, output formats, exit codes) remain identical

## Testing Strategy

- Write new extglob test FIRST (TDD), before implementation:
  ```bash
  # Test N: extglob pattern matching
  touch foo.jpg bar.png baz.gif
  output=$(glob "@(*.jpg|*.png)" 2>/dev/null)
  expected=$'bar.png\nfoo.jpg'
  assert "$output" == "$expected" "glob should handle extglob @(...) patterns"
  ```
- Run existing 54-test suite after refactor — all must continue passing
- Fix the 3 case-insensitive tests as a separate commit
- Verify the dotfile warning fix with the user's exact reproduction case:
  ```bash
  # In ~/Downloads with dotfiles present but no dotfiles matching the full pattern:
  glob '* {(Z-Library),(z-library.sk\, 1lib.sk\, z-lib.sk)}.*'
  # Should NOT warn about dotfiles
  ```

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

### Simplified
- Glob detection regex expands to recognize extglob syntax
- The entire pattern expansion loop reduces to: `compgen -G "$pattern"` with appropriate shopts

### Fixed: Dotfile Warning
Current (broken): re-expands pattern via `_dot_matches=($_pattern)` which word-splits on spaces.

New approach:
```bash
# Get matches without dotglob
mapfile -t matches_without < <(compgen -G "$pattern")
# Get matches with dotglob
shopt -s dotglob
mapfile -t matches_with < <(compgen -G "$pattern")
shopt -u dotglob
# Only warn if there are dotfile-starting entries in matches_with that aren't in matches_without
```

### Added
- `shopt -s extglob globstar` in the shopt management section
- Extglob pattern detection in the glob-detection check

### Unchanged
- Flag parsing and validation
- Brace expansion preprocessor (lines 212-243)
- Output formatting (`-0`, `-n`, `--double-quote`, default newline)
- Command mode, batch mode, dry-run, ARG_MAX checking
- The `--test` entry point
- Help text (updated to mention extglob support)

## Separate Fix: Case-Insensitive Test Failures

3 pre-existing test failures (tests 20, 21, 22) caused by macOS case-insensitive filesystem where `touch "Test.JPG" "test.Jpg" "TEST.jpg"` creates one file, not three. Fix: use filenames that differ beyond just case (e.g., `alpha.JPG`, `beta.Jpg`, `gamma.jpg`).

## Risk Assessment

- 54 passing tests cover all features and will catch regressions
- `compgen -G` is a bash builtin — no new dependencies
- Brace expansion preprocessing is preserved unchanged
- All external interfaces (flags, output formats, exit codes) remain identical

## Testing Strategy

- Run existing 54-test suite after refactor — all must continue passing
- Fix the 3 case-insensitive tests as a separate commit
- Add new test for extglob pattern support
- Verify the dotfile warning fix with the user's exact reproduction case

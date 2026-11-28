# Dotfiles cleanup and reorganization (owner request, 2026-11-28)

## The request

1. Every change must behave the same on macOS and Linux. That explains the
   current layout: Bash loads different files in different situations on each
   (macOS terminals start login shells, Linux terminal tabs usually do not), so
   `.bash_profile` sources `.bashrc` and should hold only what interactive
   login shells need.
2. Anything in `.profile` must be POSIX, unless gated behind a Bash check.
3. Delete everything about LM Studio and Homebrew, even when already
   commented out.
4. Sanity-check `.envconfig`. Keep its commented-out history, except anything
   about Homebrew or LM Studio.
5. `.pathconfig` was rebuilt around the LuaJIT startup engine. Its former,
   fairly extensive comments should live somewhere, so that the file can
   eventually be removed if PATH configuration no longer happens there. Do not
   remove it yet.
6. Can `.gitconfig.old-possibly-useful` be removed?
7. `edit` must open Zed (`zeditor` or `zed`) with its file arguments
   everywhere, or micro where Zed is unavailable.
8. Recommend general improvements: where the intent is clear but a different
   approach would serve it better, and what that gains.

## Findings so far

### `.profile` (item 2)

- Line 132 uses `${BASH_SOURCE[*]:-}` in a `case`, which is a "Bad
  substitution" error in dash; lines 16 and 173 use `${BASH_SOURCE[0]}`.
- `codex.bash`, `claude.bash`, `capture.bash` and `resolve.bash` are sourced
  without the `in_bash` gate that `agy.bash` and `shadows.bash` already use;
  `capture.bash` is sourced twice.
- Lines 176-178 are an LM Studio block.

### `.bash_profile` (item 1)

- Line 29, `A && B || C && D && E`, still appends progress after the debug
  branch fires; an `if`/`elif` states the intent.
- It sources `.pathconfig` and `session.bash` and picks `AWK` and `SED`
  itself, beyond its stated "source `.bashrc` plus interactive-only" role.
- Line 75 uses `which` instead of `command -v`.
- Lines 110-112 are LM Studio; the oMLX markers below them are kept on
  purpose so its installer finds its block.

### `.bashrc`

- Lines 378-380 are an LM Studio block. `LANG` is also set in `.envconfig`.

### `.envconfig` (item 4)

- Homebrew: the commented gcc/LLVM block (lines 107-135) and the
  `brew --prefix openssl` note on line 83. The Plan 9 lines inside the block
  are not Homebrew and can stay as history.
- `NODE_PATH=/usr/local/lib/node` predates mise; when that directory exists
  it can inject stale modules into every Node process.
- `LANG` duplicates `.bashrc`; `truthy.sh` is sourced again.
- The SSL fallbacks are checked in sequence, so the last match wins rather
  than the first.
- `TMPDIR` is forced to `/tmp` "(in memory on my OS'es)", but macOS `/tmp` is
  on disk and the default per-user `TMPDIR` there is private.

### `.pathconfig` (item 5)

It is still sourced by every startup path, but only as the bridge that runs
`lib/shell_startup/shell_env.lua` and applies its assignments; the rules live
in `lib/shell_startup/path_plan.lua`. The largest former version (334 lines,
d3fa0b6) explained rationale that did not survive: last-prepend-wins
ordering, keeping the NixOS sudo wrapper ahead of the non-setuid sudo, the
foreign-entry rule and the `nix develop` incident behind it, and the macOS
Rapid Security Response exclusions.

### `.gitconfig.old-possibly-useful` (item 6)

From 2022, superseded by `.gitconfig`; diffmerge/SourceTree tools,
`--preserve-merges` (removed from Git) and default colors are obsolete.
Possibly worth porting first: `rerere.enabled`, `diff.algorithm` (histogram),
and the `lol`, `hist` and `amend` aliases. The current `.gitconfig` sets
`core.editor = code --wait` (VS Code), which conflicts with item 7.

### `edit` (item 7)

`edit` is a function sourced only by interactive Bash (`bin/src/edit.bash`),
with no executable form, so scripts and agents lack it. `VISUAL` (zeditor or
zed, skipping the ZFS daemon) and `EDITOR` (micro) are also set only in
`.bashrc`. `choose_editor` falls back to nano, not micro, and skips `VISUAL`
whenever stdout is not a terminal.

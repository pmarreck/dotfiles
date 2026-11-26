# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Completed: preserve local work and reconcile GitHub (2026-11-25)

- [x] Preserve the current commits and uncommitted files before integration; review their purpose and tests.
  Curiosity poke: distinguish useful local behavior from duplicated upstream changes.
  Completed 2026-11-25 EST: recovery branch retains the three existing local commits; private recovery copies retain the original uncommitted files. SSH-agent discovery has eight passing checks.
- [x] Restore `AGENTS.md` as its tracked relative symlink, keeping the physical file recoverable.
  Curiosity poke: confirm the link target exists before replacing the file.
  Completed 2026-11-25 EST: the tracked relative target exists; the physical file is preserved privately and both instruction entry points resolve through symlinks.
- [x] Verify and commit the useful local changes, then merge the latest `origin/master` without rewriting existing commits.
  Curiosity poke: preserve both sides of shell startup and test-runner changes.
  Completed 2026-11-25 EST: local work committed in `1b6e9d9e` after all 202 host test files passed and the macOS Nix check passed; all 73 incoming commits are integrated without rewriting history.
- [x] Resolve conflicts and run the required merged checks.
  Completed 2026-11-25 EST: the complete entry point passed 220 hermetic Nix tests and six supplemental host tests, 226 total.
- [x] Publish the reconciled branch and verify the remote commit and Linux CI.
  Curiosity poke: confirm the final remote commit and retain recovery copies.
  Merged macOS Nix verification exposed seven upstream portability failures. Platform assertions now use the host platform; fixtures inject their tools; cache reuse compares cold and warm GC-root requests; the Yue launcher uses a binary env interpreter. Real signal-delivery assertions remain required in a separate supplemental host test, with permission checks retained in Nix.
  The dependency gate and spelling gate pass after exact spelling exceptions for quotations, encoded audio, and an external application name. The unchanged upstream license heading is a strict conflict-marker false positive; the owner approved the documented one-time exception.
  Completed 2026-11-25 EST: `3a04e750` was pushed, a fresh fetch matched local HEAD, and its exact-commit Linux Nix check succeeded. The later conflict-block change makes the license exception unnecessary for future commits.
- [x] Integrate four additional upstream commits through `47cef309` and verify their startup and command-runner changes with the preserved local work.
  Completed 2026-11-25 EST: all 228 tests passed, with 222 in Nix and six supplemental host checks.
- [x] Require a complete ordered conflict block in one staged file, with opening, separator, and closing markers; test standalone separators, partial fragments, diff3, marker sizes, and staged-content behavior before implementation.
  Completed 2026-11-25 EST: the old gate failed 12 new expectations; the updated gate passes 64 checks and the complete 228-file suite. The added upstream tmux runner needed symbolic signal-name handling on macOS; its TERM and KILL integration checks now pass. Publication remains tracked above.

## Completed: no system Python; NFC file names (2026-11-09)

- [x] `timed`: drop the python3/python clock fallbacks (perl, then whole seconds). Test simulates BSD date with no perl and asserts no Python call. Completed 2026-11-09 20:20 EST.
- [x] `mlx-server test`: pretty-print with `jq` instead of `python3 -m json.tool`; capture curl output first because jq exits 0 on empty input. New `mlx-server_test`. Completed 2026-11-09 20:22 EST.
- [x] Port `update_nix_git_hash` from Bash+Python to LuaJIT (same CLI, plus `--about`). New contract test with mocked git/nix covers dry run, tag/branch/rev resolution, rev insertion, ref override, `%FILE%`, and file restoration on all three build-failure modes. Completed 2026-11-09 20:24 EST.
- [x] Replace the vendored 4,000-line `git-filter-repo` with a launcher for `nixpkgs#git-filter-repo`. Completed 2026-11-09 20:25 EST.
- [x] Add `bin/python-stub` (linked as python, python3, pip, pip3): refuses with a flake hint; callers whose command line matches `~/.config/python-stub/allowed-callers` (untracked, per machine) get a GC-rooted `nix build nixpkgs#python3`. Needed because peon-ping's Claude hooks call python3 76 times. Completed 2026-11-09 20:27 EST.
- [x] Add `normalize-filenames` (LuaJIT): pure-Lua NFC in `bin/src/unicode_nfc.lua` with tables generated from the Unicode Character Database 17.0.0; `unicode_nfc_test` checks NormalizationTest.txt, NFC invariance of every other scalar value, and generator drift (4 mutants killed). Exclusive two-step renames; skips git work trees, bundles and metadata dirs. Completed 2026-11-09 20:36 EST.
- [x] Nightly LaunchAgent `com.pmarreck.normalize-filenames` (03:30) on Documents, Desktop, Downloads; installed and one live run verified (exit 0). Music, Movies and Pictures are excluded because catalogs track their files by path. Completed 2026-11-09 20:38 EST.
- [x] Verify the Linux Nix check (`checks.x86_64-linux.test`): completed 2026-11-25 EST for `3a04e750`, including the collision branch of `normalize-filenames_test` and the Linux `renameat2` path.

## Current

- [ ] Admit only contained tracked relative Nix `path:` inputs and matching root-parent lock nodes in the staged dependency gate, preserving absolute, traversal, untracked, malformed-parent, and symlink-escape rejection.
- [ ] Audit existing macOS ARM64 and Windows native-runner job controls for Difz and report verified runtime, memory, descendant-termination, write-confinement, and host/architecture capabilities without launching jobs or changing live state.
- [x] Profile real interactive terminal startup to first usable prompt, attribute dominant phases, make only evidence-backed reversible improvements, and verify the actual route plus login/non-login and SSH semantics (done 2026-11-25 18:24 EST; commit 588b234).
- [x] Unify the existing ./test entry point around cached Nix suite evidence plus isolated supplemental host checks, preserving complete coverage and making push verification read-only; no Home Manager migration was included (context: docs/repository-awareness.md; done 2026-10-31 12:08 EDT; commit 9bfb0ea).
- [x] Make `.pathconfig` place each `~/Code/*/bin/$PF` platform directory before every generic `~/Code/*/bin` directory in the final PATH, with classifier-style regression coverage (done 2026-10-31 11:59 EDT; commit d3fa0b6).
- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

## Recent completions

- [x] Should the push gate rerun tests on each outgoing commit? Answer: No; the approved cached-evidence design verifies each published tip without creating worktrees or running tests inside the hook (context: docs/repository-awareness.md; done 2026-10-31 10:05 EDT).

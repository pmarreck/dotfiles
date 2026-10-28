# Legacy open-work context

## Active: American English gates

- [x] Add sourced, case-insensitive rg-backed checks of staged text with explicit inflections, reviewed exceptions, failure-closed tool errors and disposable-repository tests. Completed 2026-10-28 08:14 EDT: 60 focused checks and all 178 Nix test files pass; batched staged scanning measured 0.107 seconds on this checkout.
- [x] Reuse the spelling checker in a narrow gh pr create/edit wrapper for titles, bodies and body files, preserving normal gh behavior and recording unsupported submission routes. Completed 2026-10-28 08:14 EDT: 45 fake-GitHub checks pass; the reason-required ALLOW_BRITISH_ENGLISH override is explicit and loud.

## Active: declarative mise and suite reconciliation (2026-10-23)


## Active: shared capture owner coordination (2026-10-15)

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun the expensive incident or modify the shared helper unless that owner delegates the fix.

## Active: canonical platform environment and PATH (2026-10-23)

- [x] Implement the approved `OS`/`ARCH`/`PLATFORM`/`PF`/`WSL` contract and staged current-PF project discovery. Completed 2026-10-28 03:50 EDT: commit `ea3de14`; 156/156 hermetic and 200/200 host test files passed; the 109-directory live inventory retained 99 unmigrated paths, retired 10 migrated paths and found zero mismatches; shared guidance already matched; Ollama/OpenMPT name collisions were documented and reported.
- [x] Qualify Printable Binary and RotShield current-PF commands and report to both owners and the coordinator. Completed 2026-10-28 03:50 EDT: all three native commands resolve before generic bins, raw outputs are absent, portable entries remain, `--about` PF/variant evidence passed for Printable Binary and `mrs`, the headless RotShield GUI regression was reported, and durable `llmsend` notes were delivered.

## Active: staged dependency portability gate (2026-10-23)


## Active: resumable `getfile --unzip` (2026-10-22)


## Active — nightly LaunchServices prune + siriknowledged disable (2026-10-13)


## Active: suite repair and branch reconciliation (2026-10-15)

- [x] Remove the live `steam-procs_test` snapshot race exposed by the preserved pre-push report. Completed 2026-10-28 07:37 EDT: Wine-process oracles now bracket the classifier and compare only stable pid/birth/comm/cgroup records; combined `pgrep` and Bash-native counters keep focused execution under five seconds.

## Active: Herdr layout and session identity


## Active: bedtime reminder and overnight-work offer (2026-10-13)


## Active: Linux edit desktop environment (2026-10-02)


## Active: repository maintenance and fleet report repair (2026-09-29)

- [ ] Activate the built NixOS host user timer after approval for dry-activation's unrelated desktop-service restarts; remove the shadowing imperative unit links recoverably and verify persistence.

## Active: Git remote drift reminder (2026-09-28)


## Completed: retire extracted tree generator (2026-09-23)


## Active: latest saved agent-context discovery (2026-09-23)


## Active: live wall-clock `times` command (2026-09-16)




## Completed: host-selected project binaries (2026-09-16)

- [x] Coordinate the staged `.pathconfig` migration under the cross-platform build contract without launching a fleet rewrite. Completed 2026-10-28 03:50 EDT in `ea3de14`.
- [x] Add failing-first platform, WSL, foreign-target, whitespace, idempotency, stale-PATH and shell-startup classifiers. Completed 2026-10-28 03:50 EDT with the complete Nix and host gates green.

## Active — native Herdr erect-agent-stack (2026-09-10)


## Obsidian GUI alias (2026-09-06)


## Active — bc output and GitHub reconciliation (2026-09-22)


## Active — ask_local command (2026-09-22)


## Active — let ffpw select a usable Firefox profile (2026-09-06)


## Active — sleep reminders address BDFN, not agent work (2026-09-06)


## Active — cross-host Fastfetch alias (2026-09-04)

- [ ] Reconcile the existing dirty, 25-commit-behind macOS host checkout, then pull the alias and select `.githooks` there without discarding its NVM/startup work.
  - Curiosity poke: the Mac edits overlap the same startup files changed when Volta was retired, so a blind stash/pull/pop would be a poor merge plan.

## Active — crash-safe agent tmux fleet snapshots (2026-09-02)


## Active — harden both `reformat_spaces_to_tabs` implementations (2026-08-27)


## Active — port `randompass` and `randompassdict` to LuaJIT (2026-08-27)

Locale is used only to choose an American or British spelling corpus. This
does not introduce translated UI, localized aliases, or other i18n
infrastructure; the repository-wide i18n scope decision remains unchanged.

Accepted contract: `randompass` preserves its valid-input CLI and `PWCHARSET` /
`RANDOM_SOURCE` behavior; its broader interface cleanup stays deferred.
`randompassdict` accepts `NUM_WORDS` plus an optional exact `N`, inclusive
`M-N`, or inclusive `M..N` length. Options may appear in any order; later
`--american`/`--british` wins. Native locale territory `US` selects the
American SCOWL corpus, while `C`, `POSIX`, regionless, and other territories
fall back to the current British corpus. `--no-proper-nouns` removes exactly
ASCII `^[A-Z][a-z]`, retaining acronyms and one-letter uppercase words.


## Active — port `reformat_spaces_to_tabs` to LuaJIT (2026-08-26)


## Active — retire the dotfiles-owned `glob` copy (2026-08-21)


## Active — deterministic stream grouping (2026-08-21)


## Active — Markdown frontmatter reader (2026-08-14)


## Completed — fleet repository readiness and Mechatron status (2026-08-14)


## Urgent — identify GNOME “Device memory nearly full” warning (2026-08-14)


## Active — visible, demand-sensitive fleet report (2026-08-14)


## Active — guarded public collaboration ledger (2026-08-13)


## Active — canonical PATH export gate (2026-08-06)


## Active — align Bash and Lua truthiness semantics (2026-08-06)


## Queued — identify the pipe-script approval tool (2026-08-06)

- [x] Repair `confirm`'s executable entry point under TDD and verify that denial emits zero stdout bytes while approval emits the complete buffered script. Curiosity poke: interruption, empty input, downloader failure, temporary-file cleanup, and a downstream shell that starts immediately all need fail-closed behavior. Completed 2026-10-28 04:41 EDT: direct execution now buffers before review, requires an explicit yes, cleans up on signals, and emits all approved bytes or none. Command mode observes producer failures and refuses partial output; 30 focused checks, all 201 host test files, and the hermetic Nix gate pass.

## Active — one Codex installation and updater (2026-08-04)


## Queued — Baldur's Gate 3 Proton startup failure (2026-08-04)

- [ ] Reproduce BG3's failure to load under Proton tomorrow, capture the Steam launch command, selected compatibility tool, Proton log, GPU/driver state, game-filesystem mount, and recent crash evidence before changing anything. Curiosity poke: distinguish launcher failure, DX11/Vulkan translation, filesystem permissions, stale prefix/shader cache, mods, and GPU pressure; preserve saves and the Proton prefix until the failing layer is identified.

## Active — repeat compound commands and shorten the push gate (2026-08-04)


## Queued — `show` Markdown classification regression (2026-08-05)


## Active — current-directory tmux session shorthand (2026-08-04)


## Active — cryptographically sound `randompassdict` (2026-08-04)


## Active — recent agent fleet resurrection (2026-08-03)


## Active — nightly fleet status report, all tiers (2026-07-28)


## Active — shell helper argument correctness (2026-07-27)

- [ ] ACTION REQUIRED on remaining NixOS hosts: complete the fleet-wide **mise** standard (decided 2026-08-26, superseding the earlier "drop volta, `nodejs_24` → `nodejs`" plan). Add `mise` to `environment.systemPackages` and enable `programs.nix-ld` so mise's prebuilt Node binaries run on NixOS, then `mise use -g node@lts`. Fold this into the pending combined NixOS rebuild for BDFN review.
- [ ] STALE PLIST PATHS — two LaunchAgents bake a frozen PATH snapshot containing dead `$HOME/.volta/bin`: `$HOME/Library/LaunchAgents/com.github.facebook.watchman.plist` and `$HOME/Library/LaunchAgents/com.reclip.server.plist` (the latter hardcodes a deleted Volta Node path). Regenerate them after the mise migration so they capture a clean PATH; BDFN must confirm what generates each.
- [x] `compare_dirs_test` refused pushes intermittently until the preserved report exposed second-boundary `ctime` differences between otherwise equal fixtures. Completed 2026-10-28 06:18 EDT: copy equivalence now excludes the uncopyable field, with a finite pure-core classifier test covering every retained field and multiple `ctime` mutations.
- [ ] `$HOME/.local/share/Trash/rm-safe-log` is a directory of 34,844 files (178M), one per deletion, and only grows. It was the real source of the "40,208 entries" count; the trash proper held 4,922. It is rm_safe's record, so retention is BDFN's call. Unbounded per-item log growth belongs in `$HOME/Code/rm_safe`.
- [ ] DECISION NEEDED — `~/.local/share/Trash` holds 40,208 entries and wedged `gvfsd-trash` hard enough that every `rm` on the machine blocked forever (`rm` → `rm_safe` → `gio trash`, which has no timeout at `rm-safe:1025`). Killing `gvfsd-trash` unblocked it; `gio trash` now fails fast and rm-safe falls back to its manual path. Two things to decide, neither of them mine:
  - Pruning the trash destroys recoverability, so it needs BDFN's say-so.
  - The test suite trashes its own `$TMPDIR` scratch dirs, which is both the source of the 40k entries and a cross-filesystem copy (/tmp → /home) of data that was created seconds earlier. Tests deleting their own scratch dirs arguably want real `rm`.
  - Upstream fix regardless: `rm_safe` should bound the `gio trash` call (`timeout 5 gio trash …`) so a wedged desktop daemon can never hang every `rm` on the box. Lives in `~/Code/rm_safe`, not here.

## Active — suite gating (2026-07-25)

- [ ] Decide whether to test every commit in the outgoing range (≤5, in a detached temp worktree) rather than just the tip. Mechatron judges each pushed commit against its exact-commit manifest, so a red middle commit surfaces as a real FAIL row even when the tip is green. Currently the gate tests the working tree.
  - Evidence 2026-10-28 07:40 EDT: a two-commit push enqueued and passed only the tip; the intermediate commit has no queue or history row. Base this decision on desired history integrity rather than assuming CI covers ranges.
- [x] Make `.pathconfig` place every current `$CODE/*/bin/$PF` directory ahead of every general `$CODE/*/bin` directory in the final PATH, while retaining unmigrated general and legacy paths behind both groups (done 2026-10-28 10:25 EDT; commit d3fa0b6).
- [ ] Migrate this legacy plan to the planning-work format, preserving completed history and open-item context in their canonical homes.
- [ ] Graduate tests off `NOT_HERMETIC`. The largest group only needs sibling ~/Code repos (printable-binary, rm-safe) added as flake inputs.
  - Progress 2026-10-28 05:12 EDT: graduated 10 falsely excluded or locally repairable suites (`run_test_suite`, `counted`, `strip_ansi`, `date`, `date_difference_days`, `sed`, `stat`, `histogram`, `rule30`, and `warhammer_quote`). The manifest is down to 34 explicit exclusions.
  - Progress 2026-10-28 05:28 EDT: graduated `mdff`; its fake `mdfind` now uses the Nix-resolved Bash interpreter. The manifest is down to 33.
  - Progress 2026-10-28 05:39 EDT: graduated `show`; its generated adapters use resolved interpreters, zsh completion is exercised, and the sandbox fixture preserves generated-artifact mtimes. The manifest is down to 32.
  - Progress 2026-10-28 05:55 EDT: graduated `hr`; terminal-width detection now runs in a deterministic 37-column PTY. The manifest is down to 31.
  - Progress 2026-10-28 07:03 EDT: graduated `capture`; the hermetic suite now builds PrintableBinary's canonical Zig implementation from pinned public source and toolchain inputs, and the filter emits no diagnostics. The manifest is down to 30.
  - Progress 2026-10-28 07:13 EDT: graduated `cpuhogs`; every process-data source and the CPU count were already injected, and its help capture now stays in the test-owned fixture directory. The manifest is down to 29.
  - Progress 2026-10-28 07:26 EDT: graduated `gpuhogs`; runtime fixture scripts use the resolved Bash interpreter, and the Darwin root path no longer requires `sudo` merely to discover that it will not be used. The manifest is down to 28.
  - Progress 2026-10-28 07:44 EDT: graduated `memhogs`; its generated `ps` adapter uses the resolved Bash interpreter, avoids `errexit`, and keeps help capture in the test-owned fixture directory. The manifest is down to 27.
  - Progress 2026-10-28 07:52 EDT: graduated `diskhogs`; its injected `iotop`, `fs_usage`, and `sudo` adapters now use the resolved Bash interpreter. The manifest is down to 26.
  - Progress 2026-10-28 08:13 EDT: graduated `nethogs`; a disposable-clone Nix run first reproduced all six fixture adapters failing through absent `/usr/bin/env`, then passed all 176 admitted files after resolving their Bash interpreter. The live tree then passed all 204 host files and all 179 Nix-admitted files. The manifest is down to 25.
  - Progress 2026-10-28 08:25 EDT: graduated `fingerprint_hw_os`; the first Nix run reproduced two missing-distro assertions caused by reading the sandbox host. A private Linux fixture now injects filesystem, platform, architecture, kernel, CPU, memory, DMI, OS, container, and fixed SHA inputs. Focused tests, ShellCheck, and all 180 Nix-admitted files pass. The manifest is down to 24.
  - Progress 2026-10-28 08:33 EDT: graduated `distro_pretty`; the first Nix run reproduced its three macOS adapters failing through absent `/usr/bin/env`. The test now resolves the command and Bash itself, uses a private HOME, and passes focused ShellCheck plus all 181 Nix-admitted files. The manifest is down to 23.
  - Progress 2026-10-28 08:40 EDT: graduated `find_github_forks_with_file`; the first Nix run reproduced five cases failing because the fully stubbed `gh` adapter used `/usr/bin/env`. The test now resolves its command, temp files, Bash, `gh`, and `xargs`; focused ShellCheck, all six cases, and all 182 Nix-admitted files pass. The manifest is down to 22.
  - Progress 2026-10-28 08:46 EDT: graduated `webping_curl`; the first Nix run proved its private curl adapter never executed. The test now resolves its command, temp root, and Bash without HOME or `/usr/bin/env`; focused ShellCheck, all six argument-contract cases, and all 183 Nix-admitted files pass. The manifest is down to 21.
  - Progress 2026-10-28 08:54 EDT: graduated `git_commit_ai`; the first Nix run reproduced its curl adapter failing through absent `/usr/bin/env` and captured no request. The test now uses one private repository/HOME/XDG root, resolves its command and both adapters, and proves only the staged diff is sent. Focused ShellCheck, all 184 Nix-admitted files, and all 204 host files pass. The manifest is down to 20.
  - Progress 2026-10-28 09:00 EDT: graduated `sessions`; the first Nix run reproduced eight failures because its injected tmux adapter exited 126 through absent `/usr/bin/env`. The test now resolves Bash and the command, uses one private temp root and HOME, and passes focused ShellCheck, all 13 behavior cases, all 185 Nix-admitted files, and all 204 host files. The manifest is down to 19.
  - Progress 2026-10-28 09:06 EDT: graduated `apply-hooks`; the first Nix run reproduced McFly disappearing after a second source because its adapter could not execute through `/usr/bin/env`. Both adapters now resolve Bash, and the nested shell uses a private HOME with the repository as a read-only source fixture. Focused ShellCheck, both hook lifecycle regressions, all 186 Nix-admitted files, and all 204 host files pass. The manifest is down to 18.
  - Progress 2026-10-28 09:12 EDT: graduated `newterm`; the first Nix run reproduced all three injected detach adapters exiting 126 through absent `/usr/bin/env`. The test now resolves Bash and the command, owns every case under one trap-cleaned root and private HOME, and passes focused ShellCheck, all three platform behaviors, all 187 Nix-admitted files, and all 204 host files. The manifest is down to 17.
  - Progress 2026-10-28 09:21 EDT: graduated `ask`; the first Nix run proved its success cases inherited a live API key and Glow installation. The test now supplies those adapters, resolves the command, uses private HOME/XDG/TMPDIR state, and exports every curl mock. Its negative assertions reject unrelated adapter failures. Focused ShellCheck, all four API behaviors, all 188 Nix-admitted files, and all 204 host files pass. The manifest is down to 16.
  - Progress 2026-10-28 09:24 EDT: graduated `get-all-git-stati` without code changes. Its repositories, remotes, roots, and default HOME were already disposable fixtures; the first admitted run passed all 189 Nix test files. The manifest is down to 15.
  - Progress 2026-10-28 09:33 EDT: graduated `executables`; the first Nix run proved its limited PATH selected the dotfiles `fd` guard without the real binary. The test now resolves one real provider for every dependency, discards inherited `fd`/`find` functions, and uses a private trap-cleaned root and HOME. Focused ShellCheck, the full behavior suite, all 190 Nix-admitted files, and all 204 host files pass. The manifest is down to 14.
  - Progress 2026-10-28 09:39 EDT: graduated `overview`; the first Nix run reproduced all generated commands failing through absent `/usr/bin/env`. The test now resolves every fixture shebang and the command, clears the inherited `rg` wrapper, and uses private HOME plus trap-owned storage. Focused ShellCheck, all six safety assertions, all 191 Nix-admitted files, and all 204 host files pass. The manifest is down to 13.
  - Progress 2026-10-28 09:44 EDT: graduated `epub`; the admission run reproduced all seven conversion paths failing because the generated `ebook-convert` adapter used absent `/usr/bin/env`. The test now resolves Bash and the repository root, and confines HOME and XDG state to its trap-owned tree. Focused ShellCheck, all 192 Nix-admitted files, and all 204 host files pass. The manifest is down to 12.
  - Progress 2026-10-28 09:50 EDT: graduated `darktide-sync-mods`; the admission run reproduced two host-fixture failures through absent `/usr/bin/env`. Generated adapters now use resolved Bash, all state lives under one trap-owned root, and declared `rsync` coverage replaces the prior sandbox skip. All 20 focused assertions, all 193 Nix-admitted files, and all 204 host files pass. The manifest is down to 11.
  - Progress 2026-10-28 09:56 EDT: graduated `darktide-patch-mods`; its admission run reproduced 21 fixture-interpreter failures. All executable adapters now use resolved Bash, logs are real private files, state is trap-owned, and inherited search wrappers cannot redirect `find` through live HOME. All 40 focused assertions, all 194 Nix-admitted files, and all 204 host files pass. The manifest is down to 10.
  - Progress 2026-10-28 10:03 EDT: graduated `encrypt`; its admission run exposed an encryption failure masked by a successful trailing `base64`. The test now checks each operation directly, sources tracked functions, uses private GnuPG/XDG/TMPDIR state, and runs declared GnuPG plus rage. All three round trips, all 195 Nix-admitted files, and all 204 host files pass. The manifest is down to 9.
  - Progress 2026-10-28 10:08 EDT: graduated `decrypt`; the old duplicate passed its admission run, then was reduced to a repository-relative delegate to the isolated encryption/decryption contract. Concurrent test entries now receive distinct private GnuPG roots. All 196 Nix-admitted files and all 204 host files pass. The manifest is down to 8.
  - Progress 2026-10-28 10:18 EDT: graduated `jpegxl`; the admission run reproduced 25 failures from absent `cjxl`/`djxl`. The declared libjxl toolchain now runs all 26 asserted behaviors under private state; Linux mtime detection and generated adapter shebangs are fixed. All 197 Nix-admitted files and all 204 host files pass. The manifest is down to 7.
  - Progress 2026-10-28 10:38 EDT: graduated `jpeg`; the admission run isolated two timestamp failures caused by choosing GNU `stat` and later forcing its BSD syntax. The test now reuses its resolved GNU adapter and passes all 18 behaviors plus ShellCheck. The manifest is down to 6.
  - Progress 2026-10-28 10:43 EDT: graduated `png`; its admission run reproduced the same two timestamp adapter failures and exposed reliance on an unrelated exported `STAT`. The test now resolves GNU `stat` itself, removes two unused captures, and passes all 15 behaviors plus ShellCheck. The manifest is down to 5.
  - Progress 2026-10-28 10:49 EDT: graduated `rg`; its admission run reproduced 30 fixture failures because its intentionally bounded PATH could not resolve generated or nested Bash interpreters. The test now threads one resolved Bash path through every process boundary and passes all 52 guard classifications plus ShellCheck. The manifest is down to 4.
- [ ] Migrate the 9 legacy memories still in `~/.claude/projects/*/memory/` into `~/MEMORIES` via the `memories` skill (another agent's migration is unfinished).

## Active — code-review remediation (2026-07-24/25)

Driven by `CODE_REVIEW.md` (6-reviewer audit). Wave 1 + the nix-PATH bug are done.

- [ ] Wave 2 (remaining): fail-open guards (`.profile:15`, `.envconfig:3`), `timeout` alias grouping (`.aliases:195`), dead LLM-detect regex (`.bashrc:71`, `rg --fixed-strings` vs BRE `\|`), readonly re-declare guard (`.envconfig:298`), inverted awk warning, `claude/codex.bash` empty-path guard, `/usr/bin/script` (`.aliases:106`), `ARCHFLAGS` (`.bashrc:178`), 🔒 `~/Code/*/bin` PATH-shadowing.
- [ ] Wave 3: `${EDIT}` → `${EDIT:-}` across 38 sites / 17 files (`set -u` abort).
- [ ] Wave 4: decide + execute `.shellenv` (orphaned half-finished refactor — finish+wire then delete live duplicates, or delete). NOTE: changes login-shell load order on BOTH OSes; only Linux is testable from here.

## Active — Claude updater correctness (started 2026-07-24)



- [ ] Restore the missing `$HOME/.claude/hooks/` on the affected NixOS host. Both `block-attribution/block-attribution.sh` and `block-git/block-git.sh` are absent even though the canonical brief assumes them.

## Active — cross-platform GPU observability (started 2026-07-24)

- [ ] Remove `diskhogs`' unconditional sudo requirement: provide the strongest useful unprivileged per-process view each OS permits, while reserving privileged all-user visibility for an explicit mode or on-demand collector.
  - Curiosity poke: Linux may expose same-user `/proc/<pid>/io` counters while macOS may require a narrowly privileged sampler for process attribution; do not pretend device-wide I/O is per-process evidence.

## Backlog (PARKED — revenue work comes first) — mechanically gate `--help` against the parser

**BDFN's theory, 2026-07-27:** `--help` should be derived from something
co-located with the functionality (scraped comments in interpreted languages,
generated at build time in compiled ones) so that "documented but not done" and
"done but not documented" become hard to express. He already did the
co-location half in `ixnay` — help lives beside each subcommand's parsing and is
scraped on the fly — but it is not *enforced*.

**Why this is on the list at all:** on 2026-07-27 `bin/pre-push-gate` documented
a `--check-only` flag in `_help()` that had **no branch** in its
`case "${1:-}"`. The flag was silently accepted, did nothing, and its own test
suite used it while believing it was in check-only mode. Real divergence, in a
gate whose whole job is refusing invalid states.

**Prior art (two camps):**

- *Parser from help*: `docopt` — the usage text IS the grammar, so an undocumented flag cannot exist. Ports for Python/Rust/Go/C/bash.
- *Help from code*: Rust `clap` derive (`///` doc comments → help at compile time), Go `cobra` (Short/Long on the command struct), Python `click` (decorators + docstrings). Zig `comptime` over a declaration struct gets the same at build time. `help2man` runs it backwards (scrape `--help` → man page). Newer: `usage` (jdx) — one spec file emits parser + docs + completions.

**The refinement worth keeping:** co-location alone is not enough. A comment
adjacent to the code can still lie, because comments are not executed. The
property that actually holds is **single source of truth** — one declaration
from which both the help text and the parse branch are derived, so documenting
a flag *is* implementing its parse path.

**And note the failure mode that bit us is the harder one:** `--check-only` was
not *rejected*, it was **accepted and inert**. A check of "does the documented
flag error?" would have passed, wrongly.

**Proposed gate (MFIC-shaped, cheap):** a shared test helper
`assert_help_matches_parser <cmd>` that:

1. extracts the flag set from `--help` output;
2. extracts the flag set from the parser (bash: the `case` arms; clap/cobra: reflection is free);
3. **asserts set equality in BOTH directions** — catching documented-but-unparsed and parsed-but-undocumented;
4. optional strongest rung: exercise each documented flag and assert it changes observable behavior, catching accepted-but-inert.

Step 3 alone is ~10 lines of bash and would have caught `--check-only`
statically. Because the canonical brief already mandates `-h/--help` and
`--about` on every CLI, this could become a fleet-wide standard that sits
alongside the existing test-count floor and allowlisted-skips checks — turning a
convention enforced by discipline into one enforced by the suite.

**First step when unparked:** run the helper against the existing dotfiles CLIs
and count the divergences. That number is the argument for adopting it fleet-wide.

## Backlog — resurrect BDFN's historical iTunes preferences/playlists

- [ ] Recover every historically starred/liked track and the contents/order of old playlists from the read-only legacy music archive, including Apple's old malformed/nonconforming XML metadata rather than relying only on present audio filenames.
- [ ] Inventory every candidate iTunes library/playlist metadata file, preserve originals read-only, and build a tolerant parser/repair pipeline with regression fixtures for each concrete XML violation encountered.
- [ ] Reconcile duplicate library snapshots and stable track identifiers without erasing historical evidence; retain which library/playlist asserted each like, star, membership, order, rating, and last-known file location.
- [ ] Produce a human-readable Markdown document plus structured JSON/CSV exports suitable for recreating the recovered collections in Spotify, SoundCloud, Apple Music, or later migration tooling.
  - Curiosity poke: “ever liked” may be encoded through ratings, loved/disliked flags, smart-playlist predicates, or playlist membership depending on the iTunes era; treat them as distinct provenance-bearing signals before deciding which ones belong in the final union.

## Active — collation / listing thread (started 2026-07-23)

Additive to the already-shipped fun_intro/rg/sessions work; established goals stand.

- [ ] `glob`: loud, **muteable** stderr note stating the active collation + its i18n caveat ("code-point order; non-ASCII sorts after ASCII — like rg/fd/eza"). Pure, tested note fn; mute via truthy `GLOB_MUTE_SORT_NOTE` / `--mute-sort-note`; TTY-gated so scripts/pipes/CI stay clean. Show BDFN live before fixing the default.
- [ ] `l`: promote alias → `bin/l` (preserve `le`/`l0-3`/`le0-3`/`lsize` family); default sort by name (eza already code-point & locale-independent — confirmed); add `l --date` → sort by modification date. Same transparent-note treatment.

### BIG idea (new, additive) — `collation_mf_do_you_speak_it` (Zig lib + C FFI)
Repo `pmarreck/collation_mf_do_you_speak_it` at `~/Code/`. Delegated to a
background Agent (2026-07-23); this session stays on the dotfiles queue above.
Spun out of the glob/`l` collation dive. **Gap:** glibc locale collation is
non-reproducible (glibc 2.28 reorder silently corrupted PG indexes; musl has NO
`LC_COLLATE` → byte fallback) and ICU is heavy; rg/fd/eza all punt to code-point.
**Opportunity:** a tiny, fast, *opinionated*, cross-libc/cross-OS collation library
that ships its own **versioned** data (reproducible by design), does NFC
normalization + UCA-ish tailoring for a curated language set + **natural-numeric**
sort, exposes a **C FFI** (LuaJIT/Zig/bash-helper consumers), with a **code-point
fallback**. Differentiator vs `icu4x`: small / opinionated / FFI-first / no-Rust-dep
for consumers / natural-sort baked in. End state: `glob` + `l` both consume it →
consistent, correct-ish, reproducible everywhere. Own repo (scaffold-zig-project).
Scope-first hard parts: CLDR tailoring data *source* (do NOT hand-roll tables — the
trap eza's contributor flagged), normalization data, natural+UCA interplay, SIMD
sort-keys, and a deliberate answer to "why not just bind `icu4x`?".

## Recent

- [ ] Route disposable Cargo and Zig compiler state to `/mnt/devcache` through a readiness-gated `.envconfig` policy, with repository-isolated local caches and interactive directory-change refresh.
  - Curiosity poke: existing agent processes retain old environments until a new command shell is spawned; validate both Codex and Claude empirically.
- [ ] Empirically test Codex bracketed-paste submission with the target tmux session unattached, attached and visibly shown, and attached but hidden.
  - Curiosity poke: does the outer terminal's visibility affect the pane PTY at all, or is `session_attached` the only potentially observable variable?

## Open

### Structured event emission (multi-phase, in design with project-manager)

Phase 1 scope (when implementation starts):
- `capture_json` (bash shim → LuaJIT helper, FFI write(2), printable-binary-encoded string fields, schema `"v":1`)
- minimal `structured.bash` (sourceable lib exposing emit_event / emit_out / emit_err / with_context / route_structured_to_std)
- `probe expect_empty` and `probe expect_rc` (LuaJIT-native, one fork per invocation, in-process emit)
- `with_context` (argv form only, no `--shell` yet)
- chunk-sentinel protocol for events > PIPE_BUF (4 KB), defined upfront
- event sink default: `${STRUCTURED_SINK_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}}/structured/session-$$.ndjson`

Phase 2+:
- `with_context --shell` (parse `|`/`||`/`&&`, each unit `bash -c`'d)
- `probe expect_match` / `probe expect_lt`
- Auto-titling terminal view (subscribes to context_push/pop)
- Other "views" (TUI, replay, test-assertion, aggregator)
- Mid-stream FD peeking for non-cooperative pipeline visibility
- Trace-ID env-var propagation (only if cross-fork correlation becomes needed)

Hard invariant: `structured.bash` must NEVER be transitively pulled into shell startup (`.bashrc` / `.profile` / `.pathconfig`). Opt-in only.

### LuaJIT dependency verification (revisit)

Phase-1 plan is to assume `luajit` on PATH and bail with a clear error if missing (the shebang wouldn't resolve anyway). Longer-term, decide:
- Should there be a `bin/vendor/luajit` symlink for an explicit/discoverable dep contract?
- Should the install script verify all hard deps up front (luajit, jq if we add it, printable-binary, etc.) and either warn or block?
- Should `structured.bash` self-disable (per the no-op + warn fallback) instead of bailing?

Lean toward "install script verifies + structured.bash self-disables" but no rush — defer until first new-machine bootstrap reveals the rough edges.

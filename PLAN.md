# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Current

- [x] Deliver shared 500-line/hourly repository advisories and commit/compaction adapters; installed backed-up configurations, passed 43 focused assertions and all 207 Nix test files in 53 seconds; actual context delivery after each harness reload remains to be observed (context: docs/repository-awareness.md; done 2026-10-31 09:35 EDT).
- [x] Implement approved cached test evidence for pushed tips with explicit preparation, current-platform manifest discovery and supplemental host qualification; push hooks only verify evidence and preserve custom delegates (context: docs/repository-awareness.md; done 2026-10-31 10:05 EDT).

- [x] Block ad hoc Nix-store copies through cp/install/rsync and inherited Bash functions; explain pinned flake staging, require reasoned export exceptions, and pass 135 focused checks plus all 205 Nix test files (context: docs/nix-store-copy-guard.md; done 2026-10-30 13:52 EDT).

- [x] Add configurable shared-repository branch/worktree caps with warn-at-four/max-at-five/refuse-six defaults; existing work is preserved, concurrent creation and custom hooks are covered, 60 focused checks and all 204 Nix test files pass (done 2026-10-28 13:39 EDT).
- [x] Close alias-level hook override and background-hook lock retention regressions; preserve ordinary hook configuration and release owned locks explicitly, with 64 focused checks and all 204 Nix test files passing (done 2026-10-28 13:47 EDT).

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.
- [x] Should the push gate rerun tests on each outgoing commit? Answer: No; the approved cached-evidence design verifies each published tip without creating worktrees or running tests inside the hook (context: docs/repository-awareness.md; done 2026-10-31 10:05 EDT).

## Host coordination

- [ ] Activate the built NixOS user timer after BDFN approval for the dry-activation's unrelated desktop-service restarts, then recoverably remove shadowing imperative unit links.
- [ ] Reconcile the dirty, behind macOS checkout without discarding its startup work (context: docs/plan_context/legacy-open-work.md#active--cross-host-fastfetch-alias-2026-09-04).
- [ ] Complete fleet-wide mise activation on remaining NixOS hosts and regenerate the two stale macOS LaunchAgents after identifying their generators (context: docs/plan_context/legacy-open-work.md#active--shell-helper-argument-correctness-2026-07-27).
- [ ] Restore the missing attribution and Git guard hooks on the affected NixOS host.
- [ ] Test Codex bracketed-paste submission with the target Herdr terminal unattached, visible, and attached but hidden.

## Code maintenance

- [ ] Decide whether to finish and wire `.shellenv` or remove the orphaned refactor, accounting for login-shell order on both supported operating systems.
- [ ] Decide retention for the unbounded rm-safe log and Trash backlog, then add a bounded `gio trash` timeout in the rm-safe project (context: docs/plan_context/legacy-open-work.md#active--shell-helper-argument-correctness-2026-07-27).
- [ ] Reproduce the queued Baldur's Gate 3 Proton startup failure without modifying saves or the prefix first (context: docs/plan_context/legacy-open-work.md#queued--baldurs-gate-3-proton-startup-failure-2026-08-04).
- [ ] Add the approved TTY-only, muteable collation disclosure to `glob`, showing the rendered output to BDFN before fixing assertions (context: docs/plan_context/legacy-open-work.md#active--collation--listing-thread-started-2026-07-23).
- [ ] Promote `l` from an alias to a tested command with name and modification-date ordering while preserving its alias family (context: docs/plan_context/legacy-open-work.md#active--collation--listing-thread-started-2026-07-23).

## Backlog

- [ ] Mechanically gate CLI help declarations against parser behavior in both directions, including accepted-but-inert options (context: docs/plan_context/legacy-open-work.md#backlog-parked--revenue-work-comes-first--mechanically-gate---help-against-the-parser).
- [ ] Recover historical music likes, ratings, playlists, ordering, and provenance from read-only legacy library metadata into Markdown and structured exports (context: docs/plan_context/legacy-open-work.md#backlog--resurrect-bdfns-historical-itunes-preferencesplaylists).
- [ ] Move the proposed versioned collation library into its own project plan rather than tracking its implementation here (context: docs/plan_context/legacy-open-work.md#big-idea-new-additive--collation_mf_do_you_speak_it-zig-lib--c-ffi).
- [ ] Implement the first structured-event phase only after its sink, chunking, and shell-startup isolation contracts are accepted (context: docs/plan_context/legacy-open-work.md#structured-event-emission-multi-phase-in-design-with-project-manager).
- [ ] Revisit explicit LuaJIT dependency verification after the first new-machine bootstrap exposes a concrete failure (context: docs/plan_context/legacy-open-work.md#luajit-dependency-verification-revisit).

## Recent completions

- [x] Make `diskhogs` unprivileged by default with same-user Linux `/proc` and macOS libproc byte-counter sampling, retaining explicit `--all-users` elevation through the original collectors (done 2026-10-28 11:50 EDT).
- [x] Replace 229 unsafe `${EDIT}` expansions across 153 live, generated, and dormant shell files with nounset-safe defaults after a repository-wide classifier failed on the old set; retain the byte-preserved randompass predecessor as the sole explicit exception (done 2026-10-28 11:34 EDT).
- [x] Complete code-review remediation wave 2 with one regression suite covering fail-closed startup predicates, alias grouping, parent-agent detection, reload safety, terminal guards, portable commands, architecture flags, missing-executable wrappers, and the previously completed project-bin ordering (done 2026-10-28 11:29 EDT).
- [x] Finish the readiness-gated development-cache policy: repository-isolated Cargo and Zig local caches, shared Zig global cache, prompt-time directory refresh, revocation after readiness loss, and live Codex/Claude environment verification (done 2026-10-28 11:22 EDT).

# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Current

- [x] Add configurable shared-repository branch/worktree caps with warn-at-four/max-at-five/refuse-six defaults; existing work is preserved, concurrent creation and custom hooks are covered, 60 focused checks and all 204 Nix test files pass (done 2026-10-28 13:39 EDT).

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.
- [ ] Decide whether the pre-push gate should test each outgoing commit, up to five, in detached disposable worktrees (context: docs/plan_context/legacy-open-work.md#active--suite-gating-2026-07-25).

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
- [x] Review and migrate the nine remaining legacy Claude memories into the private shared memory root, preserving their original creation instants and validating the complete index (done 2026-10-28 11:15 EDT).
- [x] Audit the seven remaining `NOT_HERMETIC` tests: graduate JPEG, PNG, search-guard, and Mandelroc coverage; retain only three tests that intentionally inspect live terminal or installed user/system state. The Nix suite now admits 201 of 204 host tests (done 2026-10-28 11:06 EDT; commits 6d20220, d251d22, 92fc570, 30d7806; context: docs/plan_context/legacy-open-work.md#active--suite-gating-2026-07-25).
- [x] Migrate the legacy plan to the planning-work format, preserving completed history and open-item context in their canonical homes (done 2026-10-28 10:31 EDT; commit e837c79).
- [x] Globally prioritize every current `$CODE/*/bin/$PF` directory ahead of every general project bin while retaining unmigrated and legacy command paths behind both groups (done 2026-10-28 10:25 EDT; commit d3fa0b6).

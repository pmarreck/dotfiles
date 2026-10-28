# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Current

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.
- [ ] Decide whether the pre-push gate should test each outgoing commit, up to five, in detached disposable worktrees (context: docs/plan_context/legacy-open-work.md#active--suite-gating-2026-07-25).

## Host coordination

- [ ] Activate the built NixOS user timer after BDFN approval for the dry-activation's unrelated desktop-service restarts, then recoverably remove shadowing imperative unit links.
- [ ] Reconcile the dirty, behind macOS checkout without discarding its startup work (context: docs/plan_context/legacy-open-work.md#active--cross-host-fastfetch-alias-2026-09-04).
- [ ] Complete fleet-wide mise activation on remaining NixOS hosts and regenerate the two stale macOS LaunchAgents after identifying their generators (context: docs/plan_context/legacy-open-work.md#active--shell-helper-argument-correctness-2026-07-27).
- [ ] Restore the missing attribution and Git guard hooks on the affected NixOS host.
- [ ] Migrate the nine remaining legacy Claude memories into the shared memory root with the `memories` skill.
- [ ] Route disposable Cargo and Zig compiler state through the readiness-gated development cache policy with repository-isolated caches and directory-change refresh.
- [ ] Test Codex bracketed-paste submission with the target Herdr terminal unattached, visible, and attached but hidden.

## Code maintenance

- [ ] Complete code-review remediation wave 2: fail-open guards, alias grouping, dead detection regex, readonly guards, warning logic, empty-path guards, portable `script`, `ARCHFLAGS`, and project-bin shadowing (context: docs/plan_context/legacy-open-work.md#active--code-review-remediation-2026-07-2425).
- [ ] Replace unsafe `${EDIT}` expansions across the remaining 38 sites, with failing `set -u` regressions first.
- [ ] Decide whether to finish and wire `.shellenv` or remove the orphaned refactor, accounting for login-shell order on both supported operating systems.
- [ ] Remove `diskhogs`' unconditional sudo requirement while preserving an explicit privileged all-user mode (context: docs/plan_context/legacy-open-work.md#active--cross-platform-gpu-observability-started-2026-07-24).
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

- [x] Audit the seven remaining `NOT_HERMETIC` tests: graduate JPEG, PNG, search-guard, and Mandelroc coverage; retain only three tests that intentionally inspect live terminal or installed user/system state. The Nix suite now admits 201 of 204 host tests (done 2026-10-28 11:06 EDT; commits 6d20220, d251d22, 92fc570, 30d7806; context: docs/plan_context/legacy-open-work.md#active--suite-gating-2026-07-25).
- [x] Migrate the legacy plan to the planning-work format, preserving completed history and open-item context in their canonical homes (done 2026-10-28 10:31 EDT; commit e837c79).
- [x] Globally prioritize every current `$CODE/*/bin/$PF` directory ahead of every general project bin while retaining unmigrated and legacy command paths behind both groups (done 2026-10-28 10:25 EDT; commit d3fa0b6).

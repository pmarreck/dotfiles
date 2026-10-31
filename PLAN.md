# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Current

- [ ] Unify the existing ./test entry point around cached Nix suite evidence plus isolated supplemental host checks, preserving complete coverage and making push verification read-only; delegated to the project agent, with no Home Manager migration in scope (context: docs/repository-awareness.md).
- [x] Make `.pathconfig` place each `~/Code/*/bin/$PF` platform directory before every generic `~/Code/*/bin` directory in the final PATH, with classifier-style regression coverage (done 2026-10-31 11:59 EDT; commit d3fa0b6).
- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

## Recent completions

- [x] Implement approved cached test evidence for pushed tips with explicit preparation, current-platform manifest discovery and supplemental host qualification; push hooks only verify evidence and preserve custom delegates (context: docs/repository-awareness.md; done 2026-10-31 10:05 EDT).
- [x] Should the push gate rerun tests on each outgoing commit? Answer: No; the approved cached-evidence design verifies each published tip without creating worktrees or running tests inside the hook (context: docs/repository-awareness.md; done 2026-10-31 10:05 EDT).

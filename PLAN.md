# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Current

- [x] Unify the existing ./test entry point around cached Nix suite evidence plus isolated supplemental host checks, preserving complete coverage and making push verification read-only; no Home Manager migration was included (context: docs/repository-awareness.md; done 2026-10-31 12:08 EDT; commit 9bfb0ea).
- [x] Make `.pathconfig` place each `~/Code/*/bin/$PF` platform directory before every generic `~/Code/*/bin` directory in the final PATH, with classifier-style regression coverage (done 2026-10-31 11:59 EDT; commit d3fa0b6).
- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

## Recent completions

- [x] Should the push gate rerun tests on each outgoing commit? Answer: No; the approved cached-evidence design verifies each published tip without creating worktrees or running tests inside the hook (context: docs/repository-awareness.md; done 2026-10-31 10:05 EDT).

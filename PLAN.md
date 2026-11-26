# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Completed: preserve local work and reconcile GitHub (2026-11-25)

- [x] Require a complete ordered conflict block in one staged file, with opening, separator, and closing markers; test standalone separators, partial fragments, diff3, marker sizes, and staged-content behavior before implementation. Completed 2026-11-25 EST: the old gate failed 12 new expectations; the updated gate passes 64 checks and the complete 228-file suite. The added upstream tmux runner needed symbolic signal-name handling on macOS; its TERM and KILL integration checks now pass. Publication remains tracked above.

## Completed: no system Python; NFC file names (2026-11-09)

- [x] Verify the Linux Nix check (`checks.x86_64-linux.test`): completed 2026-11-25 EST for `3a04e750`, including the collision branch of `normalize-filenames_test` and the Linux `renameat2` path.

## Current

- [ ] Make the staged 500-line source-file gate a strong nonblocking advisory only for the owner-approved `pmarreck/validate` repository, retaining hard enforcement everywhere else and proving the exception against spoofed repository identities in an isolated real-index/commit test.
- [x] Admit only contained tracked relative Nix `path:` inputs and matching root-parent lock nodes in the staged dependency gate, preserving absolute, traversal, untracked, malformed-parent, and symlink-escape rejection (done 2026-11-25 23:37 EST; commit 60a3867).
- [x] Audit existing macOS ARM64 and Windows native-runner job controls for Difz and report verified runtime, memory, descendant-termination, write-confinement, and host/architecture capabilities without launching jobs or changing live state; Linux is proven bounded, while macOS ARM64 and Windows AMD64 lack verified per-job envelopes and no Windows ARM64 runner was found (done 2026-11-25 23:37 EST; commit 60a3867).
- [x] Profile real interactive terminal startup to first usable prompt, attribute dominant phases, make only evidence-backed reversible improvements, and verify the actual route plus login/non-login and SSH semantics (done 2026-11-25 18:24 EST; commit 588b234).
- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## Completed: no system Python; NFC file names (2026-11-09)

- [x] Verify the Linux Nix check (`checks.x86_64-linux.test`): completed 2026-11-25 EST for `3a04e750`, including the collision branch of `normalize-filenames_test` and the Linux `renameat2` path.

## LuaJIT shell startup rewrite

- [x] Build PATH once per interactive startup and define `needs` and `array_contains_element` in the current shell, with a forked-helper budget test and a PTY time-to-first-prompt benchmark; interleaved A/B non-login 1,013 → 770 ms and login 1,067 → 885 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 12:20 EST; commit 7160838).
- [x] Compute PATH in one LuaJIT run that prints validated `NAME='value'` lines for Bash to eval, proven equal to the frozen Bash implementation by a seeded differential test, with a round-trip quoting property test, explicit luajit bootstrap candidates, and loud no-change failure; interleaved A/B non-login 755 → 705 ms and login 877 → 832 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 12:40 EST; commit baa2660).
- [x] Remove platform and distribution forks from startup: Linux DISTRO facts from the engine run (differential-tested against the distro commands), one kernel read per shell, and no is_nix_darwin or off-macOS check-system-mutations forks; uname stays in Bash because tests inject it there; interleaved A/B non-login 772 → 656 ms and login 865 → 758 ms under load average 12–19 (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 12:58 EST; commit 6fcc909).
- [ ] Read macOS distribution facts without forking sw_vers, distro_version, or mac_os_version_number_to_name, verified on the Mac (context: docs/plan_context/luajit-shell-startup.md).
- [ ] Replace GNU tool, terminal image capability, and rg string checks with cached or in-process facts (context: docs/plan_context/luajit-shell-startup.md).
- [x] Find the devcache project root in-process, matching git rev-parse --show-toplevel by oracle test, and memoize its digest; each prompt fell from about 28 ms and 8 processes to 1.8 ms and none after the first (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 13:18 EST).
- [ ] Cache starship, direnv, and mcfly init output by resolved binary path (context: docs/plan_context/luajit-shell-startup.md).
- [ ] Rebuild the terminal intro as one LuaJIT pick process with a pre-rendered Kitty stream, explicit protocol selection, and text fallback tests (context: docs/plan_context/luajit-shell-startup.md).
- [ ] Verify fresh Ghostty and WezTerm tabs, SSH commands, and scripts on each supported host, including luajit availability before PATH exists, before calling the rewrite shipped.

## Current

- [x] Make the staged 500-line source-file gate a strong nonblocking advisory only for the owner-approved `pmarreck/validate` repository, retaining hard enforcement everywhere else and proving the exception against spoofed repository identities in an isolated real-index/commit test; future entries require separate explicit owner approval in dotfiles (done 2026-11-26 10:41 EST; commit 66204dd).
- [x] Admit only contained tracked relative Nix `path:` inputs and matching root-parent lock nodes in the staged dependency gate, preserving absolute, traversal, untracked, malformed-parent, and symlink-escape rejection (done 2026-11-25 23:37 EST; commit 60a3867).
- [x] Audit existing macOS ARM64 and Windows native-runner job controls for Difz and report verified runtime, memory, descendant-termination, write-confinement, and host/architecture capabilities without launching jobs or changing live state; Linux is proven bounded, while macOS ARM64 and Windows AMD64 lack verified per-job envelopes and no Windows ARM64 runner was found (done 2026-11-25 23:37 EST; commit 60a3867).
- [x] Profile real interactive terminal startup to first usable prompt, attribute dominant phases, make only evidence-backed reversible improvements, and verify the actual route plus login/non-login and SSH semantics (done 2026-11-25 18:24 EST; commit 588b234).
- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

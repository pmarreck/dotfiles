# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## NAS mount failure reporting (2026-10-26)

- [x] Restore a green repository-wide gate before committing the NAS fix, without excluding tests: the earlier 6 isolated failures (executable-names, fun_intro, launchd-keep-disabled, lsregister-prune-dead, mandelroc, terminal_config) are gone and the full ./test passes with the fix on top of the startup rewrite (done 2026-11-27 15:20 EST).

## Completed: no system Python; NFC file names (2026-11-09)


## LuaJIT shell startup rewrite

- [x] Build PATH once per interactive startup and define `needs` and `array_contains_element` in the current shell, with a forked-helper budget test and a PTY time-to-first-prompt benchmark; interleaved A/B non-login 1,013 → 770 ms and login 1,067 → 885 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 12:20 EST; commit 7160838).
- [x] Compute PATH in one LuaJIT run that prints validated `NAME='value'` lines for Bash to eval, proven equal to the frozen Bash implementation by a seeded differential test, with a round-trip quoting property test, explicit luajit bootstrap candidates, and loud no-change failure; interleaved A/B non-login 755 → 705 ms and login 877 → 832 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 12:40 EST; commit baa2660).
- [x] Remove platform and distribution forks from startup: Linux DISTRO facts from the engine run (differential-tested against the distro commands), one kernel read per shell, and no is_nix_darwin or off-macOS check-system-mutations forks; uname stays in Bash because tests inject it there; interleaved A/B non-login 772 → 656 ms and login 865 → 758 ms under load average 12–19 (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 12:58 EST; commit 6fcc909).
- [ ] Read macOS distribution facts without forking sw_vers, distro_version, or mac_os_version_number_to_name, verified on the Mac (context: docs/plan_context/luajit-shell-startup.md).
- [x] Remove Arch Linux remnants (PAC_USE_AUR, pacman hint) per owner (done 2026-11-27 14:12 EST; commit 481b61c).
- [x] Stop git launcher copies on PATH from exec'ing each other forever, with a two-copy regression test (done 2026-11-27 14:30 EST; commit 7ccab8f).
- [ ] Verify the startup commits on the macOS and WSL hosts in fixture homes from a clean environment, then report before syncing their live checkouts.
- [x] Re-apply the WSL checkout's two unpublished commits (drop macOS-only absolute bin symlinks; propagate NAS mount failures) onto the rewrite with credit, then move that checkout to the result as the owner approved; its old head and stash are kept as local refs (done 2026-11-27 15:17 EST; commits 760809c, 2e17edc).
- [ ] Port the remaining startup helpers: GNU tool detection, the GNU awk check, and other rg or version probes (context: docs/plan_context/luajit-shell-startup.md).
- [ ] Owner decision: shell_startup_test requires node through mise shims, but the WSL host has neither mise nor node, so its host phase fails there; install them on that host or make node optional per host?
- [x] Compute SIXEL_ENV, SIXEL_CAPABLE, KITTY_CAPABLE, IMAGE_CAPABLE, and the parent process name in the startup engine instead of forking check_sixel_support, check_kitty_support, infocmp, and ps; interleaved A/B non-login 367 → 320 ms, login 467 → 429 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 15:40 EST).
- [ ] Add a headless Ghostty runner: drive the real shell on a PTY through libghostty-vt from LuaJIT and assert on the rendered screen (intro before a usable prompt, command output, image placement, no stray escapes) (context: docs/plan_context/luajit-shell-startup.md).
- [x] Find the devcache project root in-process, matching git rev-parse --show-toplevel by oracle test, and memoize its digest; each prompt fell from about 28 ms and 8 processes to 1.8 ms and none after the first (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 13:18 EST; commit bdfdff4).
- [ ] Cache starship, direnv, and mcfly init output by resolved binary path (context: docs/plan_context/luajit-shell-startup.md).
- [x] Rebuild the terminal intro as one LuaJIT process: every pick but fortune and mandelbash in Lua, pre-rendered Kitty and Sixel images (no ImageMagick at startup), memoized mandelbash, no replay cache or background regenerator; each pick differential-tested against its Bash original; live picks 4.7 to 15.6 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 15:10 EST; commit 204fbfa).
- [ ] Verify fresh Ghostty and WezTerm tabs, SSH commands, and scripts on each supported host, including luajit availability before PATH exists, before calling the rewrite shipped.

## Current

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

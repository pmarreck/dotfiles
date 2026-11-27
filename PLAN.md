# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## NAS mount failure reporting (2026-10-26)

- [x] Restore a green repository-wide gate before committing the NAS fix, without excluding tests: the earlier 6 isolated failures (executable-names, fun_intro, launchd-keep-disabled, lsregister-prune-dead, mandelroc, terminal_config) are gone and the full ./test passes with the fix on top of the startup rewrite (done 2026-11-27 15:20 EST).

## Completed: no system Python; NFC file names (2026-11-09)


## LuaJIT shell startup rewrite

- [x] Read macOS distribution facts without forking sw_vers, distro_version, or mac_os_version_number_to_name: the engine reads SystemVersion.plist and the script's own case table, .bashrc keeps the commands as fallback; verified on the Mac (identical values, zero runs, about 34 ms saved per startup) (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 17:35 EST).
- [ ] Verify the startup commits on the macOS and WSL hosts in fixture homes from a clean environment, then report before syncing their live checkouts.
- [x] Re-apply the WSL checkout's two unpublished commits (drop macOS-only absolute bin symlinks; propagate NAS mount failures) onto the rewrite with credit, then move that checkout to the result as the owner approved; its old head and stash are kept as local refs (done 2026-11-27 15:17 EST; commits 760809c, 2e17edc).
- [x] Port the remaining startup helpers: GNU tool paths and the login sed choice now come from the engine's cached --version answers, and the GNU awk check runs only where its warning can fire; startup execve calls 152 → 12, interleaved A/B non-login 324 → 259 ms, login 400 → 312 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 16:15 EST).
- [x] Remove the last one-off startup execs: exclude_path filters in Bash (no which or awk), TMPDIR and GPG_TTY come from the engine, and the tabs gate uses a builtin; a non-login startup now makes 9 execve calls: LuaJIT and its wrapper, three uname reads, mcfly and direnv init, sha256sum for the devcache digest, and bash (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 16:35 EST).
- [ ] Owner decision: shell_startup_test requires node through mise shims, but the WSL host has neither mise nor node, so its host phase fails there; install them on that host or make node optional per host?
- [x] Compute SIXEL_ENV, SIXEL_CAPABLE, KITTY_CAPABLE, IMAGE_CAPABLE, and the parent process name in the startup engine instead of forking check_sixel_support, check_kitty_support, infocmp, and ps; interleaved A/B non-login 367 → 320 ms, login 467 → 429 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 15:40 EST).
- [x] Add a headless Ghostty runner: real Bash on a PTY through libghostty-vt from LuaJIT, asserting on the rendered screen; hermetic checks cover query replies, Kitty placement, and every intro pick through the .profile gate, and a host test covers the live login and non-login startup; it found mandelbash swallowing the next character (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 15:55 EST).
- [x] Stop mandelbash leaving a /tmp/m<pid> file behind on every run: it removes its tee file after reading it, output unchanged byte for byte, and mandelroc_test now asserts the file is gone instead of deleting it (done 2026-11-27 16:45 EST).
- [x] Cache starship, direnv, and mcfly init output: the engine keeps each init script in an immutable file keyed by invoked path, resolved path, size, mtime, and arguments, and apply-hooks evaluates it when the shell would run that binary; interleaved A/B, 20 samples: non-login 249 → 236 ms, login 291 → 277 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 17:20 EST).
- [x] Rebuild the terminal intro as one LuaJIT process: every pick but fortune and mandelbash in Lua, pre-rendered Kitty and Sixel images (no ImageMagick at startup), memoized mandelbash, no replay cache or background regenerator; each pick differential-tested against its Bash original; live picks 4.7 to 15.6 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 15:10 EST; commit 204fbfa).
- [ ] Verify fresh Ghostty and WezTerm tabs, SSH commands, and scripts on each supported host, including luajit availability before PATH exists, before calling the rewrite shipped.

## Current

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## NAS mount failure reporting (2026-10-26)


## Completed: no system Python; NFC file names (2026-11-09)


## LuaJIT shell startup rewrite

- [x] Read macOS distribution facts without forking sw_vers, distro_version, or mac_os_version_number_to_name: the engine reads SystemVersion.plist and the script's own case table, .bashrc keeps the commands as fallback; verified on the Mac (identical values, zero runs, about 34 ms saved per startup) (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 17:35 EST).
- [x] Verify the startup commits on the macOS and WSL hosts in fixture homes from a clean environment: at add2a62 the Mac passes all 249 test files; the WSL host passes all but the node/mise host gap below, and its live checkout was fast-forwarded to add2a62 as authorized (done 2026-11-27 17:40 EST).
- [x] Guard against runaway wrapper recursion: PATH-shadowing wrappers count nested hand-offs in the exported DOTFILES_WRAPPER_DEPTH and refuse past 10, and run_test_suite stops any test file still running after DOTFILES_TEST_TIMEOUT (300 s) together with everything it started; requested after a red-control copy of the tree recursed through the live chmod wrapper (done 2026-11-27 18:05 EST).
- [x] Owner decision: sync the Mac's live checkout (was at bb89f559) to the verified commit? Answer: yes; it was clean and was fast-forwarded to 36625bc after the Mac passed all 250 test files there (done 2026-11-27 19:55 EST).
- [x] Owner decision: shell_startup_test requires node through mise shims, but the WSL host had neither mise nor node; install them or make node optional? Answer: install them. mise is now in the WSL host's NixOS config (local commit 07bb17c in its nix_machine_configs checkout, not pushed), Node LTS comes from mise with prebuilt binaries (nix-ld), and the host passes all 250 test files (done 2026-11-27 19:55 EST).
- [x] Stop mandelbash leaving a /tmp/m<pid> file behind on every run: it removes its tee file after reading it, output unchanged byte for byte, and mandelroc_test now asserts the file is gone instead of deleting it (done 2026-11-27 16:45 EST).
- [x] Cache starship, direnv, and mcfly init output: the engine keeps each init script in an immutable file keyed by invoked path, resolved path, size, mtime, and arguments, and apply-hooks evaluates it when the shell would run that binary; interleaved A/B, 20 samples: non-login 249 → 236 ms, login 291 → 277 ms (context: docs/plan_context/luajit-shell-startup.md; done 2026-11-27 17:20 EST).
- [ ] Verify fresh Ghostty and WezTerm tabs, SSH commands, and scripts on each supported host, including luajit availability before PATH exists, before calling the rewrite shipped.

## Host configuration drift coverage (2026-11-28)

- [x] Warn agents about unpushed or unintegrated commits in this host's configuration repositories (the checkout behind /etc/nixos, a top-level XDG config repository, REPO_AWARENESS_HOST_REPOS), from any working directory; prompted by a NixOS checkout that sat 24 commits ahead for 35 days (done 2026-11-28 01:00 EST; commit 9cb529e).
- [x] Fetch those repositories daily so behind counts stay current: host-config-fetch plus install-host-config-fetch for a systemd user timer or a macOS LaunchAgent (done 2026-11-28 01:15 EST; commit b589eeb).
- [ ] Push dotfiles, fast-forward the Framework, Mac and WSL host, install the repo-awareness hooks and the fetch schedule on every host, and verify the warning and a live fetch on each.

## Dotfiles cleanup (owner request 2026-11-28)

- [ ] Keep startup identical on macOS and Linux: .bash_profile sources .bashrc and holds only interactive-login work; move everything else where every shell type reaches it, with tests (context: docs/plan_context/dotfiles-cleanup.md).
- [ ] Make .profile POSIX: gate every Bash-only line behind in_bash, drop the duplicate capture.bash source, and add a dash parse-and-run test (context: docs/plan_context/dotfiles-cleanup.md).
- [ ] Delete every LM Studio and Homebrew remnant from the startup files, commented-out ones included.
- [ ] Sanity-check .envconfig, keeping commented history except Homebrew and LM Studio: NODE_PATH, duplicate LANG and truthy, SSL fallback order, macOS TMPDIR (context: docs/plan_context/dotfiles-cleanup.md).
- [ ] Preserve .pathconfig's lost rationale beside the engine rules it explains, and propose how to retire .pathconfig later without removing it now (context: docs/plan_context/dotfiles-cleanup.md).
- [x] Owner question: can .gitconfig.old-possibly-useful be removed? Answer: yes; it is a 2022 config superseded by .gitconfig and kept in Git history, with only rerere, a diff algorithm and a few aliases arguably worth porting first (context: docs/plan_context/dotfiles-cleanup.md; done 2026-11-28 01:25 EST).
- [ ] Delete .gitconfig.old-possibly-useful once the owner confirms, porting whatever they want kept.
- [ ] Make `edit` open Zed (zeditor or zed) with its file arguments wherever a GUI is reachable, else micro: an executable for non-interactive callers, micro instead of nano as the fallback, the same choice in every shell, and git's core.editor (context: docs/plan_context/dotfiles-cleanup.md).
- [ ] Write the general-improvement recommendations the owner asked for: clear intent, better method, and the gain of each.

## Current

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

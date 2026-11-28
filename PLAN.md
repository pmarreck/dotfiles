# PLAN

Open work is listed in priority order. Completed history is in `docs/PLAN_LOG.md`; background for migrated legacy items is in `docs/plan_context/legacy-open-work.md`.

## NAS mount failure reporting (2026-10-26)


## Completed: no system Python; NFC file names (2026-11-09)


## LuaJIT shell startup rewrite

- [ ] Verify fresh Ghostty and WezTerm tabs, SSH commands, and scripts on each supported host, including luajit availability before PATH exists, before calling the rewrite shipped.

## Host configuration drift coverage (2026-11-28)


## Dotfiles cleanup (owner request 2026-11-28)

- [x] Keep startup identical on macOS and Linux: the session helper moved to .bashrc, duplicated version and AWK checks left .bash_profile, and the debug-or-progress precedence bug is fixed in three files; GNU sed is still chosen twice, see recommendation 2 (context: docs/plan_context/dotfiles-cleanup.md; done 2026-11-28 02:05 EST; commit ef86777).
- [x] Make .profile POSIX: Bash-only parts gated behind in_bash, the duplicate capture.bash source removed, and profile_posix_test runs it under dash (context: docs/plan_context/dotfiles-cleanup.md; done 2026-11-28 02:05 EST; commit ef86777).
- [x] Delete every LM Studio and Homebrew remnant from the startup files, commented-out ones included, plus install hints in scripts and two Homebrew helper scripts (done 2026-11-28 02:05 EST; commit ef86777).
- [x] Sanity-check .envconfig: NODE_PATH removed, truthy sourced only when missing, the duplicate LANG removed from .bashrc, certificate fallback order documented; macOS TMPDIR left for the owner as recommendation 9 (context: docs/plan_context/dotfiles-cleanup.md; done 2026-11-28 02:05 EST; commit ef86777).
- [x] Preserve .pathconfig's lost rationale: docs/shell-startup-path.md, linked from path_plan.lua and .pathconfig, with a staged proposal to retire .pathconfig later; nothing removed (done 2026-11-28 02:05 EST; commit ef86777).
- [x] Merge the dotfiles-cleanup branch into master, push, and fast-forward every host: all 256 test files passed on Linux, macOS and WSL, and fresh shells on the Framework, Mac and WSL host set VISUAL to choose_editor --wait locally and leave it unset over SSH (owner approved; done 2026-11-28 09:35 EST; pushed 00e24b7).
- [ ] Delete .gitconfig.old-possibly-useful once the owner confirms, porting whatever they want kept.
- [x] Make `edit` open Zed (zeditor or zed) with its file arguments wherever a GUI is reachable, else micro: choose_editor applies that policy, a new edit executable serves non-interactive callers, and git's core.editor is choose_editor --wait; VISUAL is unchanged, see recommendation 6 (done 2026-11-28 02:05 EST; commit 2f8fa3e).
- [x] Make VISUAL wait too (owner approved recommendation 6): VISUAL is choose_editor --wait outside SSH and unset over SSH, so crontab -e, sudoedit and Bash's Ctrl-X Ctrl-E read the file after Zed closes it (done 2026-11-28 09:23 EST; commit 58eceeb).
- [x] Detect assistant shells by the parent process name alone, codex included: matching "claude" in $0 and $_ (paths) skipped the prompt hooks whenever a home or temporary directory path contained the word (owner request; done 2026-11-28 09:34 EST; commit 2902192).
- [x] Write the general-improvement recommendations the owner asked for: docs/dotfiles-recommendations.md, 15 entries with intent, better method and gain (done 2026-11-28 02:05 EST; commit ef86777).
- [ ] Owner decision: which entries in docs/dotfiles-recommendations.md to adopt; 6 was adopted 2026-11-28, and no other entry is started until chosen.

## Current

- [ ] Await Mechatron Prime's owned `capture`/`strace -f` child-pipe deadlock regression and placement decision; do not rerun or modify the shared helper without delegation.

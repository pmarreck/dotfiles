# Dotfiles recommendations (2026-11-28)

Requested as part of the dotfiles cleanup: where the intent is clear but a
different approach would serve it better, and what that gains. Each entry
names the intent, the alternative, and the gain. Findings come from the
2026-11-28 cleanup and four-host rollout; `CODE_REVIEW.md` (2026-07-24) has
older findings, several of which have since been fixed.

## Startup structure

1. **One interactive entry point.** Intent: every interactive shell behaves the
   same on macOS (where each terminal tab is a login shell) and Linux (where it
   usually is not). Today interactive setup is spread across `.bash_profile`,
   `.bashrc`, `.profile`, `.envconfig` and `.shellenv`, which is how the tmux
   `session` helper ended up only in login shells, so Linux tabs never had it
   (moved to `.bashrc` in this cleanup). Instead, keep `.bash_profile` to
   login-only warnings plus `source ~/.bashrc`, and give each concern one owner
   file that `.bashrc` sources in a fixed order. Gain: a whole class of "works
   in a Mac tab, missing in a Linux tab" bugs disappears, and each setting has
   one home.

2. **Choose GNU sed once.** Intent: scripts use GNU sed everywhere. The engine
   picks `SED` from the PATH a shell arrived with, then `.bash_profile`
   discards that and picks again from the rebuilt PATH, so login and non-login
   shells can end up with different `sed` paths. Instead, have the engine pick
   once, on the rebuilt PATH, and delete the `.bash_profile` loop and the
   `SHELL_STARTUP_LOGIN_SED` output. Gain: identical choices in every shell,
   and less code.

3. **Finish or delete `.shellenv`.** Intent: non-interactive shells (`ssh host
   cmd`, scripts) get the environment too. `.shellenv` still says its
   `BASH_ENV` wiring is "TBD", so it runs only in tests; this was the July
   review's top item and is still open. Instead, either wire
   `BASH_ENV=~/.shellenv` for non-interactive Bash and remove the blocks it
   duplicates, or delete it. Gain: one known environment for scripts instead
   of whatever the parent shell exported.

4. **Give POSIX login shells the same PATH.** Intent: `.profile` serves any
   login shell. It is now POSIX-clean, but under `sh` it skips `.pathconfig`
   (Bash) and so builds no PATH. The engine's output is already POSIX
   (`NAME='value'` lines), so a short POSIX bridge in `.profile` could run it
   and `eval` the result. Gain: `sh -l`, display-manager sessions and other
   non-Bash logins get the PATH every Bash shell gets.

5. **Retire the `.pathconfig` name gradually.** See
   `docs/shell-startup-path.md`: move the bridge to
   `bin/src/shell_startup.bash`, keep `~/.pathconfig` as a one-line shim for a
   while, then remove it. Gain: the file's name stops implying that PATH rules
   live in it.

## Editors

6. **Make VISUAL block.** Intent: tools open your editor. `VISUAL=zeditor`
   returns immediately, so tools that wait for the editor to exit (`crontab
   -e`, `sudoedit`, Bash's `fc`) see an unchanged file. Instead, set
   `VISUAL='choose_editor --wait'` (or `zeditor --wait`) and keep
   `EDITOR=micro`. Gain: every tool follows the same Zed-or-micro policy git
   now uses, and waits correctly.

7. **Avoid the `code` name collision.** Intent: `code <name>` jumps to a
   project. VS Code's CLI is also `code`, and git's editor was `code --wait`,
   which does not exist on the three hosts without VS Code, so a commit
   without `-m` there had no editor to open (fixed in this cleanup). Instead, give the jump function a name no editor ships, or
   at least never rely on `code` meaning VS Code. Gain: no command whose
   meaning depends on the host.

## Per-machine values in a public repository

8. **Move machine-specific Git settings to a local include.** Intent: one
   shared `.gitconfig`. It carries a CodeRabbit `machineId` (one machine's
   identifier, committed publicly) and an absolute `gh` path that happens to
   exist on NixOS and nix-darwin. Instead, add `[include] path =
   ~/.gitconfig.local` (untracked) for per-machine keys, and call `gh` by name.
   Gain: no per-machine churn and no identifiers in a public repository.

9. **Reconsider `TMPDIR=/tmp` on macOS.** Intent: one fast temp location
   ("in memory on my OS'es"). On Linux `/tmp` is tmpfs, but on macOS it is on
   disk, and overriding `TMPDIR` drops the private per-user directory macOS
   provides. Instead, override only on Linux, and on macOS keep the system's
   `TMPDIR` (or create a RAM disk deliberately if the speed matters). Gain:
   the behavior the comment promises, without weakening macOS temp-file
   isolation.

## Declarative over imperative

10. **Declare the new timers and hooks in system configuration.** Intent:
    every host gets the drift warning and the daily fetch. Tonight they were
    installed with `install-repo-awareness-hooks` and
    `install-host-config-fetch`, which leave untracked state on each host.
    Instead, declare the systemd user timer in each NixOS configuration (as
    Thelio's `fleet-status.nix` already does for fleet upkeep) and the
    LaunchAgent in nix-darwin. Gain: a rebuild recreates them, and a new host
    gets them without anyone remembering to run installers.

11. **Do not let agent hooks depend on `LUA_CPATH`.** Intent: the
    repo-awareness hook runs in every agent session. On the Framework, the
    system LuaJIT finds `cjson` only through `LUA_CPATH` from the login
    environment, so an agent started outside a login shell would get an error
    on every event. Instead, add a cjson-enabled LuaJIT at a stable,
    GC-rooted path (as shell startup already does for its own LuaJIT) to the
    hook's fallback list. Gain: hooks work however the agent was launched.

## Tests and tools

12. **Fix `normalize-filenames` on normalizing filesystems.** The Framework's
    root ZFS dataset uses `normalization=formD`, so renaming a decomposed name
    to its composed form lands on the same directory entry: the tool reports a
    false collision and the name stays decomposed. Instead, treat a target that
    is the same file (same device and inode) as an alias and rename through a
    temporary name. Gain: the tool works on ZFS with normalization and on
    other normalization-insensitive filesystems, and the suite passes on the
    Framework.

13. **Make `host_checkup_test` host-independent.** In the machine-config
    repository it evaluates `nixosConfigurations."<hostname>"`, but tiki's
    hostname (`tiki-wsl`) differs from its configuration name
    (`tiki-wsl-nixos`). Instead, select the configuration whose
    `networking.hostName` matches. Gain: the suite passes on every host.

14. **Stop routing temporary-directory cleanup through the Trash.** Intent:
    `rm` is safe by default. Tests and scripts that remove their own `mktemp`
    directories with `command rm -rf` still reach the rm-safe `rm` on PATH
    (`command` skips functions and aliases, not executables). Thelio's Trash
    held 192,233 entries on 2026-11-28, roughly half named like `mktemp`
    output. Instead, add a dotfiles helper that permanently removes only a
    directory the same process created with `mktemp` (refusing anything else),
    and use it in test traps. rm-safe itself stays as it is. Gain: the Trash
    keeps meaning "things I might want back". The policy decision is yours.

15. **Keep commented-out history somewhere searchable, not inline.** Intent:
    preserve old configuration for posterity. Large commented blocks (old git
    helpers in `.profile`, Ruby and IRC settings in `.envconfig`) make the live
    files hard to scan. Instead, move them to one `docs/startup-history.md`,
    grouped by file, with the date each was retired. Gain: short startup files
    and history that is easier to find than in `git log -p`.

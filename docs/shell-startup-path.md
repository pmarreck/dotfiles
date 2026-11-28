# How shell startup builds PATH, and why

PATH used to be built by `.pathconfig` in Bash, with the reasons written as
comments beside each rule. The rules now live in LuaJIT,
`lib/shell_startup/path_plan.lua`, run once per shell by
`lib/shell_startup/shell_env.lua`. `.pathconfig` remains only as the bridge
that runs the engine and applies its output. This document keeps the reasons,
organized by rule. The former Bash implementation, comments included, is
preserved verbatim as the differential test's oracle in
`bin/test/fixtures/pathconfig_reference/pathconfig.bash`.

## The rebuild is idempotent; there is no "already loaded" guard

PATH is rebuilt from `ORIG_PATH` every time, so sourcing again always produces
the same result. A `_PATHCONFIG_LOADED` guard was removed on 2026-05-17 after
it caused a staleness bug: an agent inherited PATH from the shell that
launched it but never rebuilt it, because the unexported flag was unset in the
child and so masked a stale PATH snapshot. When construction is idempotent,
"skip if already loaded" trades a few milliseconds for a real staleness trap.

## `ORIG_PATH`: captured once, exported, never read-only

The pristine PATH is captured once per session (`: "${ORIG_PATH:=$PATH}"`) and
exported, so every child shell rebuilds from the same original. It is
deliberately not read-only: a child cannot correct an inherited read-only
snapshot, and the documented re-capture after a NixOS rebuild
(`unset ORIG_PATH; . ~/.pathconfig`) would fail with "cannot unset: readonly
variable" in exactly the shell that needs it.

## Additions are declarative, and the last one listed ends up first

`M.declared_additions` lists the directories to add. Entries later in the list
end up closer to the front of PATH (last prepend wins), and directories that
do not exist are skipped. Among them:

- mise shims supply Node only. Shims rather than `mise activate`, so
  non-interactive shells get `node` too and PATH never changes per directory;
  they sit behind the Nix entries so Nix wins any name collision.
- On macOS, the Nix profiles are listed so Nix tools take precedence over the
  system's.
- Vendor-installed agent CLIs (`~/.antigravity/.../bin`, `~/.grok/bin`,
  `~/.omlx/bin`) are declared here rather than where their installers put
  them. An installer appends a raw `export PATH=...:$PATH` to `.bashrc` or
  `.bash_profile`, which lands after PATH is built and escapes its ordering and
  de-duplication. The oMLX installer also once replaced the `~/.bash_profile`
  symlink with an edited copy; check for that after running it.

## Personal project commands are discovered, with a deny-list

`M.discover` collects command directories from projects under `$CODE`: each
project's generic `bin/` and its `bin/<PF>/` for the current platform, gathered
as two groups so every native `bin/<PF>/` precedes every generic `bin/` after
the last-prepend-wins rebuild. A project that has not yet migrated keeps its
old `result/bin` and `zig-out/bin` entries, behind the generic group; as soon
as `bin/<PF>/` exists, those raw build outputs leave PATH for that project.
Other platforms' directories and arbitrary nested `bin` children are never
admitted.

`M.CODE_BIN_DENYLIST` keeps named projects out entirely. Auto-discovery is a
convenience for live personal tools, but a dormant project with generic
command names captures those names for the whole machine. `mpnetwork`'s
`bin/` held `yarn`, `mocha`, `s`, `scale`, `secret`, `predeps`,
`dbup`/`dbdown` and `version.bump`, 2023-era deploy helpers for one Elixir app;
its `yarn` was the only `yarn` on PATH, so `yarn` anywhere ran that wrapper.
Projects are denied by exact name before an entry is ever added.

## Some entries are always excluded

`M.PATH_EXCLUSIONS` removes directories that keep reinserting themselves,
mostly macOS system paths such as the Rapid Security Response cryptex mounts
(see Apple's deployment guide on Rapid Security Responses).

## Foreign entries survive the rebuild

Rebuilding from `ORIG_PATH` would treat every entry not in the pristine base
as stale. But `ORIG_PATH` is inherited, so a child shell's copy predates any
tool that injected an entry since, and a naive rebuild silently deletes those
injections. That once broke `nix shell` and `nix develop` in every interactive
shell: the store `bin` directory vanished before the prompt appeared.
(`nix develop -c cmd` never sources startup files, which is why it went
unnoticed; direnv survived because its hook re-applies PATH at every prompt.)

So the rebuild keeps a set difference rather than "ORIG_PATH and nothing
else":

    foreign = current PATH - ORIG_PATH - declared additions

Foreign entries keep their order at the front; the pristine base keeps its
order at the back. The engine classifies against the PATH the shell arrived
with, never a PATH already altered by startup's own bootstrap: a transient
bootstrap entry mistaken for a foreign one would be re-hoisted to the front,
which on NixOS would put the raw, non-setuid system `sudo` ahead of its
privileged wrapper (`bin/test/pathconfig_bash_prepend_test`).

## Platform bootstrap

- NixOS owns its own ordering, because its privileged wrappers
  (`/run/wrappers/bin`) must stay ahead of the raw system binaries.
- On macOS, a modern Bash from Nix must be reachable early, so
  `#!/usr/bin/env bash` scripts do not fall back to `/bin/bash` 3.2;
  `.pathconfig` warns when neither Nix profile provides Bash.
- On macOS, `nix-daemon.sh` is sourced for its environment variables
  (`NIX_PATH`, `NIX_SSL_CERT_FILE`, ...), its PATH changes are discarded, and it
  is skipped once `NIX_PATH` is set, because it costs about 50 ms.

## Retiring `.pathconfig` later (proposal, not done)

`.pathconfig` can be removed once nothing needs its name. Today `.bashrc`,
`.bash_profile`, `.profile`, `.shellenv`, `bin/rehash`, the startup tests and
the documented re-capture command all source `~/.pathconfig`. A path there:

1. Move the bridge (LuaJIT discovery, the engine call, the exports) into
   `bin/src/shell_startup.bash`, and source that from every startup file.
2. Keep `~/.pathconfig` for a while as a one-line file that sources it, so old
   shells, scripts and muscle memory keep working.
3. Update the tests and the re-capture instructions, then delete the shim.

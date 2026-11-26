# Platform environment and project command discovery

Shell startup exports one canonical execution-platform tuple before constructing
`PATH`:

| Variable | Values | Meaning |
| --- | --- | --- |
| `OS` | `linux`, `macos`, `mswin` | Operating system family |
| `ARCH` | `amd64`, `arm64` | Execution architecture |
| `PLATFORM` | `<OS>-<ARCH>` | Full execution platform |
| `PF` | `<OS>-<ARCH>` | Short alias equal to `PLATFORM` |
| `WSL` | `0`, `1` | Whether the current Linux kernel is WSL |

The supported set is `macos-arm64`, `linux-amd64`, `linux-arm64`,
`mswin-amd64`, and `mswin-arm64`. Unsupported pairs, including
`macos-amd64`, stop PATH construction with an error. WSL retains a Linux PF;
only `WSL` distinguishes it from native Linux. Classification reads the current
kernel, so stale inherited values do not survive an SSH or child-shell boundary.

`bin/src/platform_env.bash` owns normalization. `.pathconfig` invokes it before
project discovery, and `.envconfig` invokes the same idempotent helper before
its OS-specific settings. Runtime branches that need only an operating system
must read `OS`; `PLATFORM` no longer has its historical OS-only meaning.

`PLATFORM` is exported, and some third-party build systems use that same name
for Docker or Make target syntax. Audit such scripts before invoking them from
an initialized shell; use `env -u PLATFORM COMMAND` when the external build
owns the variable and supplies its own default.

## Project command precedence

Canonical project discovery examines only immediate `$HOME/Code/*/bin` and
`bin/<PF>` directories. The staged compatibility path also examines exact
`result/bin` and `zig-out/bin` directories for unmigrated projects. Discovery
does not recurse, admit a foreign PF, or run Nix or a language build during
startup.

For a project with an existing `bin/<PF>` directory, command precedence is:

1. `bin/<PF>`
2. portable scripts in `bin`

Its raw `result/bin` and `zig-out/bin` directories are excluded, including
copies inherited from an older parent shell. For an unmigrated project with no
current-PF directory, startup temporarily preserves the previous precedence:

1. `bin`
2. `zig-out/bin`
3. `result/bin`

Only directories that exist are added, so a legacy-only project without
generic `bin` remains reachable during migration.

This per-project cutover keeps existing commands reachable while projects move
independently. Existing cross-project ordering and unrelated PATH injections
are preserved. Re-sourcing `.pathconfig` produces the same environment and
PATH.

## Project migration

Before creating `bin/<PF>`, stage and verify every user-facing native command
needed on that platform. Keep portable scripts directly in `bin`. Generated
foreign-target executables, test drivers, diagnostics, and other build-only
artifacts need not become global shell commands.

After staging the directory, refresh the current shell and clear any remembered
command locations:

```bash
. "$HOME/.pathconfig"
hash -r
command -v COMMAND
```

Removing or moving the PF directory recoverably and re-sourcing `.pathconfig`
restores that project's legacy discovery. The complete regression gate is
`./test`; focused contracts live in `bin/test/platform_env_test`,
`bin/test/pathconfig_pf_test`, and `bin/test/shell_startup_test`.

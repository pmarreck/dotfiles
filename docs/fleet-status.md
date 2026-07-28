# fleet-status

`fleet-status` is a JSON-first Git fleet health report. Its Tier 1 collector is
local, free, and network-independent: it scans `~/Code` by default, records
loss-risk state, then feeds pure one-line and Markdown renderers. Each root
means the root itself (when it is a repository) plus repositories that are its
direct children. Nested vendored dependencies, build downloads, and fixture
repositories are deliberately excluded from the fleet-project set.

The action-focused one-liner names the repositories requiring attention. After
the first run it reports only changes from the preceding snapshot unless
`--full` is supplied. Cosmetic detached HEADs—whose commits remain reachable
from a local branch—stay in the Markdown context rather than becoming false
loss alarms.

## Usage

```text
fleet-status
fleet-status --full
fleet-status --format json
fleet-status --format markdown
fleet-status --root ~/Code --root ~/another-root
fleet-status --tier 1
```

Tier 1 records:

- separate staged, modified, and untracked counts;
- detached HEAD state and the exact commits reachable from HEAD but no local
  branch;
- every local branch's configured upstream and locally known ahead/behind
  counts;
- repositories with no remote;
- stash count, HEAD SHA, current branch, and last-commit timestamp.

Collection uses Git plumbing and porcelain v2. It performs no fetch and uses no
Linux-only `/proc` paths or LuaJIT FFI syscall constants, so the same collector
works on Linux and macOS.

## State

The default state directory is
`${XDG_STATE_HOME:-$HOME/.local/state}/fleet-status/`:

- `current.json` — latest complete collector output;
- `previous.json` — the preceding complete run;
- `report.md` — the latest human-readable report.

Writes use a same-directory temporary file followed by atomic rename. A failed
or interrupted collection cannot replace `current.json`. Use `--state-dir DIR`
for an alternate location or `--no-save` for read-only collection/rendering.

## Nightly scheduling

Linux uses the committed systemd user units:

```text
install-fleet-status-timer
systemctl --user status fleet-status.timer
```

The installer links the exact committed service and timer into
`~/.config/systemd/user/`, refuses to overwrite any conflicting file or
symlink, reloads the user manager, and enables the timer immediately. The timer
runs nightly at approximately 03:15 local time, catches missed runs after
suspend/offline periods, and adds a small randomized delay.

The macOS equivalent is a `launchd` user LaunchAgent under
`~/Library/LaunchAgents/` with `ProgramArguments` pointing to
`~/dotfiles/bin/fleet-status --tier 1`, a `StartCalendarInterval` for the
nightly hour, and `RunAtLoad` if catch-up-on-login is desired. Ensure the
LaunchAgent supplies a PATH containing LuaJIT and Git. The repository documents
that mapping but does not install a LaunchAgent yet.

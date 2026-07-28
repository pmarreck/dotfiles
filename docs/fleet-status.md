# fleet-status

`fleet-status` is a JSON-first Git fleet health report. Its fast Tier 1 and 2
collectors are local, free, and network-independent; `--all` adds cached
network drift and CI context. It scans `~/Code` by default, records loss-risk
state, then feeds pure one-line and Markdown renderers. Each root
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
fleet-status --tier 2
fleet-status --all
fleet-status --all --jobs 8 --cache-ttl-hours 12
```

Tier 1 records:

- separate staged, modified, and untracked counts;
- detached HEAD state and the exact commits reachable from HEAD but no local
  branch;
- every local branch's configured upstream and locally known ahead/behind
  counts;
- repositories with no remote;
- stash count, HEAD SHA, current branch, and last-commit timestamp.

If decisive Git plumbing fails, the affected field and tier become `unknown`
or `partial`; failure is never encoded as a clean working tree, a safe detached
HEAD, an empty branch set, or a zero stash count. The one-liner names these
repositories under its `unknown` category.

Tier 2 extends the local snapshot with explicit configured/no-upstream/unknown
sync state for every branch and integer last-commit age in days for both
repositories and branches. It still performs no network access; ahead/behind
reflects the locally stored upstream refs.

The remaining tiers are slow context. They are present in JSON and Markdown
but deliberately never make the immediate-action one-liner noisy:

- Tier 3 asks GitHub for the actual fork parent and compares default branches.
  It does not assume an `upstream` remote exists. `behind`, `ahead`, and
  `diverged` remain distinct.
- Tier 4 compares every GitHub-backed `flake.lock` input and direct dependency
  pins found in `build.zig.zon`, `Cargo.lock`, `package-lock.json`, and
  `pnpm-lock.yaml`. Commit staleness and time staleness are separate JSON
  values. An immutable or unrecognized source is `unknown`, never guessed.
- Tier 5 reads the last local Mechatron Prime result and records whether
  `.mechatron-prime/targets` is missing. It does not create webhooks, targets,
  badges, or any other external state.

All external providers are read-only. GitHub calls use `gh`, registry lookups
use `curl`, and CI history uses `mechatron-ci log --json`. Provider failures,
rate limits, malformed responses, and unsupported pins become field-level
`"unknown"` values while collection still exits successfully. Network results
are cached for 24 hours by default. Each repository cache includes a fingerprint
of its origin, branch/HEAD identity, lockfiles, and Mechatron target manifest,
so a local edit invalidates the composite immediately. Successful provider
responses are separately shared by exact command to avoid repeating the same
GitHub or registry query across dependencies. Failed/malformed queries are
negative-cached for at most 15 minutes, preventing a rate limit from being
hammered while allowing recovery much sooner than the normal TTL. Every
provider subprocess has a 30-second deadline (override with
`FLEET_STATUS_PROVIDER_TIMEOUT_SECONDS`). `--cache-ttl-hours 0` disables both
cache layers; `--jobs N` bounds portable `xargs -P` worker concurrency.

Collection uses Git plumbing and porcelain v2. It performs no fetch and uses no
Linux-only `/proc` paths or LuaJIT FFI syscall constants, so the same collector
works on Linux and macOS.

## State

The default state directory is
`${XDG_STATE_HOME:-$HOME/.local/state}/fleet-status/`:

- `current.json` — latest complete collector output;
- `previous.json` — the preceding complete run;
- `report.md` — the latest human-readable report.
- `network-cache/` — independently reusable per-repository Tier 3–5 results.

Writes use a same-directory temporary file followed by atomic rename. A failed
or interrupted collection cannot replace `current.json`. An atomic state lock
prevents overlapping timer/manual runs from interleaving `current.json`,
`previous.json`, and `report.md`. Use `--state-dir DIR` for an alternate
location or `--no-save` for read-only collection/rendering; JSON `--no-save`
also remains usable if an old rendering snapshot is malformed.

## Nightly scheduling

Linux uses the committed systemd user units:

```text
install-fleet-status-timer
systemctl --user status fleet-status.timer
```

The installer links the exact committed service and timer into
`~/.config/systemd/user/`, refuses to overwrite any conflicting file or
symlink, reloads the user manager, and enables the timer immediately. The timer
runs `fleet-status --all` nightly at approximately 03:15 local time, catches
missed runs after suspend/offline periods, and adds a small randomized delay.
Use `fleet-status --tier 1` interactively when only the fast loss-risk answer
is wanted.

The macOS equivalent is a `launchd` user LaunchAgent under
`~/Library/LaunchAgents/` with separate `ProgramArguments` entries for the
absolute path to `~/dotfiles/bin/fleet-status` and `--all`, plus:

```xml
<key>StartCalendarInterval</key>
<dict>
	<key>Hour</key><integer>3</integer>
	<key>Minute</key><integer>15</integer>
</dict>
<key>RunAtLoad</key><true/>
```

Set `StandardOutPath` and `StandardErrorPath` to files under the user Library
if launch diagnostics are desired. Supply a PATH containing LuaJIT, Git, `gh`,
`curl`, `mechatron-ci`, and the standard macOS `find`/`xargs`; no GNU-only
flags, `/proc`, or platform-specific FFI constants are used. The repository
documents this mapping but does not install a LaunchAgent.

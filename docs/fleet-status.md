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
- stash count, HEAD SHA, current branch, and last-commit timestamp;
- direct Markdown inbox-message count and oldest mtime; and
- every linked Git worktree's path, branch, HEAD, and last-commit age;
- root `README.md` and conventional `LICENSE`/`LICENCE`/`COPYING` presence; and
- a canonical Mechatron endpoint badge in the first 40 README lines, matched by
  repository badge path rather than one fixed CI hostname.

If decisive Git plumbing fails, the affected field and tier become `unknown`
or `partial`; failure is never encoded as a clean working tree, a safe detached
HEAD, an empty branch set, or a zero stash count. The one-liner names these
repositories under its `unknown` category.

Tier 2 extends the local snapshot with explicit configured/no-upstream/unknown
sync state for every branch and integer last-commit age in days for both
repositories and branches. It still performs no network access; ahead/behind
reflects the locally stored upstream refs.

The Markdown report begins with `Repos Requiring Special Attention`. Its pure
classifier uses snapshot timestamps rather than reading the clock. Default
thresholds are 50 commits behind an upstream parent, a common ancestor at least
90 days old, 10 dirty files, a linked worktree idle for more than seven days,
more than one direct inbox message, or an oldest inbox message over one day.
Missing README/license documents, partial Mechatron configuration, and a
configured current HEAD that is failing, unknown, or unbuilt are also explicit
triggers. Each row states the measured reason. A GitHub compare merge-base
timestamp is the fork-synchronization proxy; inbox file mtime is the age
fallback because an inbox note is not required to contain durable message
metadata.

`Repository readiness` reports every repository's README filename, license
filename and mechanically identified SPDX type, primary language, Mechatron
configuration, and current-HEAD state. GitHub supplies license and language
metadata where available. Tokei supplies the primary-language fallback for
local or provider-unavailable repositories. Missing and ambiguous license
types remain `unknown`.

The remaining tiers are slow context. They are present in JSON and Markdown
but deliberately never make the immediate-action one-liner noisy:

- Tier 3 asks GitHub for the actual fork parent and compares default branches.
  It does not assume an `upstream` remote exists. `behind`, `ahead`, and
  `diverged` remain distinct.
- Tier 4 compares every GitHub-backed `flake.lock` input and direct dependency
  pins found in `build.zig.zon`, `Cargo.lock`, `package-lock.json`, and
  `pnpm-lock.yaml`. Commit staleness and time staleness are separate JSON
  values. An immutable or unrecognized source is `unknown`, never guessed.
- Tier 5 distinguishes an absent, badge-only, targets-only, or complete
  Mechatron Prime setup. Complete and partial setups query the exact local HEAD,
  reporting `passing`, `failing`, `building`, `queued`, `not run`, or `unknown`.
  A passing result from an older commit cannot mark the current checkout green.
  Collection does not create webhooks, targets, badges, or any other external
  state.

All external providers are read-only. GitHub calls use `gh`, registry lookups
use `curl`, local language measurement uses `tokei`, and CI state uses
HEAD-filtered `mechatron-ci log` and `queue` queries. Provider failures,
rate limits, malformed responses, and unsupported pins become field-level
`"unknown"` values while collection still exits successfully. Network results
live in an atomic per-repository cache. A daily run fully refreshes repositories
whose newest local branch commit, GitHub-origin push, or known fork-parent push
is at most seven days old. Every quiet GitHub repository receives one
lightweight origin query every seven days; quiet forks also query their parent.
A changed remote immediately escalates that repository to a full refresh. This
catches commits pushed from another machine even when the local checkout has
not moved. Repositories without GitHub remotes carry their observations until
local network inputs change, while unknown fork classifications retry weekly.

Each repository cache includes a fingerprint of its origin, branch/HEAD
identity, lockfiles, Mechatron target manifest, and bounded root-document
classification, so a meaningful local edit invalidates that repository
immediately. License type and primary language carry forward with the complete
observation while that fingerprint remains unchanged and the weekly remote
probe finds no change. Every carried value retains its full observation and
remote-probe timestamp (the compatibility field remains
`upstream_probed_at_epoch`) in the JSON snapshot. Successful
provider responses are separately shared by exact command for 24 hours by
default to avoid repeating the same GitHub or registry query across
dependencies. Failed/malformed queries are
negative-cached for at most 15 minutes, preventing a rate limit from being
hammered while allowing recovery much sooner than the normal TTL. Every
provider subprocess has a 30-second deadline (override with
`FLEET_STATUS_PROVIDER_TIMEOUT_SECONDS`). `--cache-ttl-hours 0` disables both
cache layers; `--jobs N` bounds portable `xargs -P` worker concurrency.
If a scheduled refresh or probe fails, the last complete per-repository
observation remains in the report with its original check timestamp instead of
being replaced by a false `unknown` result.

Collection uses Git plumbing and porcelain v2. `fleet-status` itself performs no
fetch and uses no Linux-only `/proc` paths or LuaJIT FFI syscall constants.
`repo-maintenance` is the nightly driver: it fetches due remotes first, then
runs the collector. Both commands work on Linux and macOS with Nix-provided
dependencies.

`repo-maintenance --dry-run` shows the exact due/deferred set without network
fetches or report writes. `--max-fetches N` overrides the default cap of 20
sequential fetches per run. Never-fetched remotes take priority, then remotes
with the oldest successful fetch timestamp; deferred work stays due for the
next run. The classifier reuses the collector's single NUL-delimited Git
status pass, so non-documentation counts do not trigger a second exhaustive
scan of large worktrees.

## Architecture

`lib/fleet_status.lua` is the stable composition root. It wires a small
hexagonal core whose dependencies point inward through constructor-injected
ports:

- `renderers.lua`, `repository_profile.lua`, and `lock_parsers.lua` are pure
  domain functions;
- `network.lua` orchestrates Tier 3–5 collection only through injected runtime,
  state, parser, and provider ports;
- `local_collector.lua` adapts local Git plumbing into the canonical snapshot;
- `state.lua` adapts canonical JSON and atomic snapshot persistence;
- `providers.lua` adapts deadline-bounded external provider commands and their
  response cache;
- `runtime.lua` is the sole general-purpose process/filesystem host adapter.

The facade preserves the original function API and canonical output bytes.
`fleet-status-architecture_test` enforces the exact module graph, pure-module
boundaries, absence of direct host I/O in network orchestration, facade size,
and substitution of fake runtime ports.

## State

The default state directory is
`${XDG_STATE_HOME:-$HOME/.local/state}/fleet-status/`:

- `current.json` — latest complete collector output;
- `previous.json` — the preceding complete run;
- `report.md` — the latest human-readable report.
- `network-cache/` — independently reusable per-repository Tier 3–5 results.

The canonical current/previous JSON snapshots plus independently timestamped
per-repository cache are the carry-forward data model. An append-only NDJSON
journal would add replay and retention cost without improving the requested
daily report or recovery behavior, so none is written.

Saved runs publish the same Markdown bytes to the visible
`$HOME/Code/Fleet Status.md` path when the viewed-or-weekly gate is due. The
nightly driver appends each run's fetch results, non-documentation uncommitted
work, and fleet delta to `$HOME/Code/Fleet Status History.md`. Blocks start with
`<!-- repo-maintenance:begin -->` and end with `<!-- repo-maintenance:end -->`.
Override the latest-report destination with
`--report-path PATH` or `FLEET_STATUS_REPORT_PATH`; the XDG directory remains
the authoritative JSON and network-cache location. A custom `--state-dir`
without an explicit report path confines publication to that state directory;
this prevents isolated tests from overwriting a real report.

Writes use a same-directory temporary file followed by atomic rename. A failed
or interrupted collection cannot replace `current.json`. An atomic state lock
prevents overlapping timer/manual runs from interleaving `current.json`,
`previous.json`, and `report.md`. Use `--state-dir DIR` for an alternate
location or `--no-save` for read-only collection/rendering; JSON `--no-save`
also remains usable if an old rendering snapshot is malformed.

## Nightly scheduling

The Thelio declares the systemd user service and timer in
`/etc/nixos/system76_thelio_nixos/fleet-status.nix`. After a NixOS switch,
`systemctl --user status fleet-status.timer` shows the active schedule.
Other Linux hosts can install the committed fallback units:

```text
install-fleet-status-timer
systemctl --user status fleet-status.timer
```

The installer links the exact committed service and timer into
`~/.config/systemd/user/`, refuses to overwrite any conflicting file or
symlink, reloads the user manager, and enables the timer immediately. The timer
runs `repo-maintenance` at approximately 03:15
local time, catches missed runs after suspend/offline periods, and adds a small
randomized delay. A repository's fetch interval is
`min(15, floor(days_since_latest_local_commit / 2) + 1)` days. The first due day
is staggered with BLAKE3 of its checkout path plus remote URL; later due dates use the last
successful fetch. At most 20 remotes are attempted per run. Fetches are
sequential, noninteractive, limited to 120 seconds each, and never merge or
change a checkout. Structured local state is
collected daily, while slow network fields follow the per-repository hot/quiet
schedule above. When the visible
report has been accessed, the next daily timer republishes it. If it remains
unread, visible publication occurs after seven days. Missing reports and
backward clock movement also trigger publication.
On Thelio, the NixOS user unit is the declarative owner; the installer is for
hosts without that module.
Use `fleet-status --tier 1` interactively when only the fast loss-risk answer
is wanted.

The macOS equivalent is a `launchd` user LaunchAgent under
`~/Library/LaunchAgents/` with separate `ProgramArguments` entries for the
absolute path to `~/dotfiles/bin/repo-maintenance`, plus:

```xml
<key>StartCalendarInterval</key>
<dict>
	<key>Hour</key><integer>3</integer>
	<key>Minute</key><integer>15</integer>
</dict>
<key>RunAtLoad</key><true/>
```

Set `StandardOutPath` and `StandardErrorPath` to files under the user Library
if launch diagnostics are desired. Supply a PATH containing LuaJIT, Git,
`b3sum`, GNU `gtimeout`, `gh`, `curl`, `mechatron-ci`, and the standard macOS
`find`/`xargs`; no Linux-only `/proc` API is used, and the lock uses the
cross-platform `flock` call. The repository
documents this mapping but does not install a LaunchAgent.

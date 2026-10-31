# Repository awareness

`repo-awareness` measures Git state once and presents it through small harness
adapters. It never fetches, stages, commits, pushes or runs tests.

The default dirty-work reminder starts at 500 non-Markdown added plus removed
lines and repeats at most hourly. It asks for a coherent, genuinely green
increment and a commit, explicitly forbidding removed, skipped or weakened test
coverage as a way to satisfy the reminder. That instruction is not a mechanical
proof that coverage was preserved. Independent test review and existing coverage
controls still matter.

The primary count is the net diff between HEAD and the working tree, plus
untracked text. Staged changes are reported separately, because staged edits can
be undone in the working tree without removing them from the index. Either count
can trigger the reminder; they are not summed, which would double-count ordinary
staged work. Binary files and unmeasured inputs are reported separately. An unborn
repository counts current tracked file contents, including edits after staging.
Untracked reads have a shared 4 MiB budget and exclude symlinks. The count is a
useful bounded estimate, not a claim to have read every byte in the repository.

More than one outgoing commit, or any incoming commits, produces a separate
hourly advisory. A post-commit hook always reports the current counts. Local
commits are never blocked by drift. Missing upstreams produce **unknown**, not
zero. Incoming counts reflect cached remote-tracking refs; fetching remains a
separate operation.

## Configuration

```sh
git config repoAwareness.dirtyLines 500
git config repoAwareness.dirtyInterval 3600
repo-awareness --json --repo .
repo-awareness --commit --repo .
install-repo-awareness-hooks
```

`REPO_DIRTY_LINES` and `REPO_DIRTY_INTERVAL` override the corresponding Git
settings. Positive integer values are required; invalid values use the defaults.
State lives under `$XDG_STATE_HOME/repo-awareness`, or
`$HOME/.local/state/repo-awareness`. Each repository/session gets independent
state and a nonblocking lock. Ordinary events sample at most every 30 seconds;
the hourly deadline and compaction bypass that cache. Clock rollback permits a
fresh reminder. Tests inject `REPO_AWARENESS_NOW`; normal operation uses wall time.

The installer preserves unrelated configuration and stores a backup before
replacing each changed file. Repeated installation is a no-op. It replaces the
older Git-status and Git-drift notifications, not time, inbox or safety hooks.
It does not change hook trust approvals; reload/restart a harness and accept its
hook configuration review if that harness requires one.
The implementation uses POSIX shell tools and `flock` through LuaJIT. Linux is
tested; macOS uses its corresponding open flags but has not been qualified for
this change. Native Windows is not covered; WSL uses the Linux implementation.

## Harness events and limits

| Harness | Regular delivery | Compaction recovery |
|---|---|---|
| Codex | PostToolUse, UserPromptSubmit | SessionStart with source `compact` |
| Claude Code | PostToolUse, UserPromptSubmit | SessionStart with source `compact` |
| Grok Build | PostToolUse, PreToolUse | PostCompact marks pending; next supported tool hook delivers |
| Gemini CLI | AfterTool, BeforeAgent | PreCompress marks pending; next supported event delivers |

Grok imports Claude hooks by default. Its `GROK_SESSION_ID` identifies the host
even for an imported adapter, so a prompt event that discards context cannot
consume the pending reminder. Both hook sources share the debounce state.
Gemini's precompression marker may also produce a reminder after an abandoned
compression; it is deliberately an advisory, not a claim that compaction finished.
Neither fallback guarantees injection before the very first postcompaction model
call. Configuration tests verify emitted hooks and simulated payloads; they do
not establish delivery inside every installed harness version.

The global Git dispatcher and the repository-budget wrapper preserve existing
post-commit hooks. The wrapper also covers custom hook directories. Native Git
invoked with a different custom hook directory can bypass the shared dispatcher;
this remains an accidental-error control, not an adversarial sandbox.

## Push-test policy under discussion

Do not turn a push into an unannounced full test run. The proposed hard gate
checks already-successful Nix check outputs for the **pushed revision**, rather
than accepting an unrelated checkout's last green result. `nix path-info` does
not build or substitute outputs. Evaluation must also disallow import-from-
derivation builds, remain offline and have a bounded timeout. Absent or stale
evidence needs an explicit diagnosis, not an automatic rebuild.

The alternative is to leave pushes unrestricted and require green CI before
merge/release. Selection and rollout of that hard gate are pending. Existing
project-specific pre-push hooks remain unchanged, including hooks that run tests.
No new push-test gate is installed by `install-repo-awareness-hooks`.

Mechatron Prime CI invokes ordinary `nix build`, not forced `--rebuild`. Identical
derivations with available successful outputs can therefore reuse results;
different platforms, source inputs or test definitions still need their own
results. A cached derivation proves its declared check succeeded, not that its
author declared a complete suite or preserved every important assertion.
Source filtering matters: the current dotfiles check uses the entire flake source,
so even a changed bookkeeping file changes its derivation. A cached-evidence gate
cannot pretend that result still matches. Source filtering would need its own
review to exclude only inputs that truly cannot affect the check.

References: [Codex hooks](https://learn.chatgpt.com/docs/hooks),
[Claude Code hooks](https://code.claude.com/docs/en/hooks),
[Gemini CLI hooks](https://geminicli.com/docs/hooks/reference/), and Grok Build's
installed `docs/user-guide/10-hooks.md`. The installed Nix `path-info --help`
documents its no-build/no-substitution behavior.

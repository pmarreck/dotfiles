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

## Cached test evidence before pushing

Do not turn a push into an unannounced full test run. The hard gate
checks already-successful Nix check outputs for each **pushed commit tip**, rather
than accepting an unrelated checkout's last green result. `nix path-info` does
not build or substitute outputs. Evaluation must also disallow import-from-
derivation builds, remain offline and have a bounded timeout. Absent or stale
evidence needs an explicit diagnosis, not an automatic rebuild.

`git-push-evidence` reads the actual ref updates supplied by Git. Every changed
tip must qualify; annotated tags resolve to their commits. Deletions and unchanged
refs need no evidence. Intermediate commits are not individually qualified: the
gate establishes the tested state at each published tip. Dirty working files
never substitute for the pushed source. Bare repositories and tags of noncommit
objects are refused rather than falsely labeled tested.

Declare required attributes in a tracked `.push-checks` file, one
`checks.SYSTEM.NAME` per line. Blank lines and `#` comments are allowed. Without
that file, the gate uses the current host platform's `checks.*` entries in the
committed `.mechatron-prime/targets` manifest. The host is identified from the
LuaJIT runtime's OS and architecture; cross-OS checks stay with CI. Packages are
not accepted as test evidence. Explicit declarations can require other platforms
too, provided their successful outputs have been obtained from trusted builders.
An explicit owner-configured `git config --add pushEvidence.check ATTRIBUTE`
overrides file selection. Missing declarations or missing flakes refuse the
push and explain what is needed; they never imply a green suite. The check list
must describe the complete required suite, including applicable integration
checks. Only the owner changes its scope; agents must not reduce it to pass.

```sh
# Preferred complete preparation: build/reuse Nix, then run host-only checks.
./test
# Nix-only preparation remains available for repositories without host checks.
git-push-evidence --prepare HEAD
# Query only. The push hook performs the same kind of verification.
git-push-evidence --check HEAD
git push
```

The query runs offline, refuses lock updates and import-from-derivation builds,
and has a 10-second timeout. `git config pushEvidence.timeoutSeconds N` can set
1..120 seconds. Preparation is explicit and permits ordinary pinned dependency
downloads. No human-readable log or arbitrary project-written green marker
replaces Nix's realized check output. A collected output, missing input cache or
cold evaluation timeout refuses the push; the diagnostic gives the preparation
command. Evaluation itself is not guaranteed to be instantaneous.

The global dispatcher and PATH Git wrapper apply the gate and preserve existing
hook arguments, input bytes and failure status, including custom hook directories.
Repeated shared dispatch for the same repository/ref input is suppressed. Direct
native Git with custom hooks or `--no-verify` can bypass local enforcement; this
is an accidental-error control, not a protected remote policy. Unrelated custom
pre-push hooks are preserved and may still run their own tests until migrated.

Dotfiles' root `./test` is the one complete entry point. It builds or reuses
`checks.<system>.test`, validates that check's structured inventory evidence,
then runs only the exact host-only set in `bin/test/NOT_HERMETIC`. The same
manifest selects the host phase and its exact complement in Nix, so neither
phase can silently omit or duplicate a test. The Nix sandbox currently owns 210
files and the supplemental host phase owns four; a cached Nix result therefore
does not rerun 210 files merely to qualify four host checks.

`pre-push-gate --check-only` is retained as a compatibility spelling for
`./test`. Hook mode is read-only: it never launches tests or writes evidence.
The test floor, skip allowlist, explicit completion summary and failure checks
still apply. The runner writes an atomic machine result whose destination is
removed from child environments; child output that happens to begin with
`PASS` or `FAIL` cannot inflate, suppress or forge suite totals. `./test`
reports Nix setup/build time, the hermetic execution time carried by the cached
result, supplemental host execution time and total wall time separately.

A clean successful `./test` records a host qualification under
`$XDG_STATE_HOME/dotfiles-host-evidence` (with the usual HOME fallback), keyed by
repository, exact commit, kernel, system profile, and the resolved Bash, Nix,
Git and LuaJIT executables and versions actually used by the host phase. Raw
PATH ordering is not identity when it resolves those same runtimes. The key does
not evaluate an unused development shell. A real rerun invalidates the old
qualification before testing; failure leaves it invalid. Checkout/runtime
changes prevent recording success. Injected
test runners never create qualifications. These local receipts are writable
accident-prevention records, not signatures or proof that arbitrary host state
has remained unchanged. The reproducible Nix check remains independently required.

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

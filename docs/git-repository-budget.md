# Shared repository branch and worktree budgets

The `bin/git` PATH wrapper defaults to five local branches and five registered
working checkouts per Git common directory. This includes the primary branch
and checkout; remote-tracking refs and tags do not count. A bare repository's
administrative entry is not a working checkout. Detached, locked and stale
registered worktrees do count until deliberately retired or pruned.

- Reaching four prints `WARNING`, with one remaining slot.
- Reaching five prints `MAXIMUM`, with a reminder to finish existing work.
- Attempting an increase beyond five prints `BLOCKED` and fails.

The branch notice in a prepared transaction describes its prospective count;
Git may still reject the operation for another reason. A successful worktree
addition reports its actual resulting count. Existing over-limit repositories
can update existing branches, commit, merge, switch, rename branches and remove
work. This gate does not delete anything or automatically raise limits.

## Configuration

The two positive integer limits are independent and use ordinary Git config
precedence. They default to five when absent:

```sh
git config --global agentLimits.maxBranches 5
git config --global agentLimits.maxWorktrees 5
```

An owner-approved repository exception can use `--local` instead of `--global`.
The warning threshold is always one below the configured maximum. Invalid,
zero or negative limits refuse growth. Limits may be lowered below existing
counts without blocking cleanup. Agents must not change these settings to
escape the budget; configuration is the owner's deliberate policy control.

## Enforcement

The wrapper resolves the underlying Git executable and preserves its arguments,
streams and exit status. Creation-capable operations hold an advisory OS lock
in the common Git directory across inspection and execution, so participating
creators in different linked worktrees cannot race for the last slot. Kernel
lock ownership ends when the processes exit; the persistent lock filename is
not a stale-lock marker and must not be deleted to unlock it.

The reference-transaction check computes the prospective local branch set from
current refs and the transaction's additions/deletions, rather than assuming
an all-zero old value means a new branch. This covers ordinary branch creation,
switch/checkout creation, first commits, update-ref and local-head fetches.
Git's native branch-copy operation can bypass that hook and receives a separate
preflight check. Worktree additions, including detached/no-checkout additions,
are checked before native Git can create their directories or branches.

A per-invocation hook adapter delegates all existing hooks, retaining their
arguments, stdin and exit codes. It does not rewrite repository hook settings.
This also covers repositories with custom `core.hooksPath`. The shared global
reference hook separately checks native Git callers that use that hook chain.
Normal Git aliases are resolved for worktree checks; shell aliases remain Git's
responsibility and their Git calls must resolve through the PATH wrapper.

This is an accidental-proliferation control. Explicit invocation of another
Git binary, libraries that edit refs/worktrees directly, deliberately changed
hook configuration or policy, and nonparticipating concurrent writers can evade
some checks. Direct native callers do not participate in the wrapper's shared
lock, and the reference hook alone cannot cover branch-copy or detached-worktree
creation. It is not a security boundary against unrestricted agents.

## Agent allocation and cleanup

The parent assigns a checkout and branch to each subagent, accounting for any
harness-generated worktree. A child requests an additional allocation rather
than creating one. Reuse available checkouts or serialize tasks when full.
On completion, report the result commit, uncommitted work and cleanup readiness;
the parent integrates the work and verifies preservation before retiring it.

Inspect with `git worktree list --porcelain` and
`git for-each-ref --format='%(refname)' refs/heads`. Do not assume a detached,
old or quiet worktree is disposable. Confirm dirty files, unpublished commits,
integration and active agent ownership. Remove obsolete worktrees through Git,
not recursive filesystem deletion; prune registrations only after checking that
missing paths are not temporarily unavailable storage.

The complete `./test` runner includes real disposable-repository controls for
thresholds, overrides, native creation paths, hook delegation, over-limit cleanup
and concurrent creators. Linux enforcement is qualified locally; the LuaJIT
POSIX adapter also implements macOS locking, but native macOS qualification is
required before claiming it tested there.

References: [Git reference-transaction hooks](https://git-scm.com/docs/githooks#_reference_transaction)
and [Git worktree administration](https://git-scm.com/docs/git-worktree).

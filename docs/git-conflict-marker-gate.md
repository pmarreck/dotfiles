# Git conflict-marker gate

The shared Git configuration selects `.global-githooks`. Its `pre-commit`
and `pre-merge-commit` hooks run `bin/git-staged-gates` before any existing
repository hook. That runner checks conflict markers first, then dependency
portability. The dotfiles repository's local `.githooks` path uses the same
runner. Dependency scope and its separate override are documented in
[`git-dependency-portability-gate.md`](git-dependency-portability-gate.md).

The gate checks the **complete staged contents** of added, copied, modified,
renamed and type-changed text files. Unstaged edits do not affect the result.
Deleted paths, binary blobs, symlink targets and submodule contents are not
scanned. It recognizes start-of-line conflict marker runs of at least seven
characters: `<`, `=`, `>`, and diff3's `|`. Labels require whitespace after
the run; separator lines permit trailing whitespace. Custom marker sizes
below seven characters are outside this check.

Failures report filenames and line numbers. Operational inspection errors
also refuse the commit. Deliberate conflict-marker fixtures and documentation
can use this explicit, warning-producing bypass:

```sh
ALLOW_GIT_CONFLICT_MARKERS=1 git commit -m 'Add deliberate conflict fixture'
```

Only the conflict-marker check is bypassed. Other repository hooks still run.
The variable must equal `1`; `0` and other values do not bypass anything.

## Existing hooks

Global dispatchers forward standard Git hooks to the shared Git directory's
`hooks/`, preserving arguments, stdin and exit status. This also works in
linked worktrees. Automatic merges fall back to a local `pre-commit` hook
when no local `pre-merge-commit` exists. Recursive delegation fails explicitly.

A repository-local `core.hooksPath` overrides the global selection. To retain
a custom hook directory while enabling the global gate, first back up the
repository's Git config, then save the old path and remove the override:

```sh
git config --local conflictMarkerGate.delegateHooksPath .githooks
git config --local --unset core.hooksPath
```

The delegate path retains Git's usual relative-path meaning: relative to the
hook's working directory. Missing old hook directories need no delegation;
after a config backup, remove the stale override to use the default hooks.
The dotfiles installer intentionally keeps its own tracked hook directory;
its added `pre-commit` provides the same gate there.

This is an accidental-error guard. Git's `--no-verify`, a later hooks-path
override, plumbing commands and editing the scripts can bypass client hooks.
Do not describe it as a security boundary or remote enforcement.

## Tests

`bin/test/git-conflict-marker-gate_test` uses isolated real repositories and
is automatically included in `./test`. It covers marker/non-marker sets,
partial staging, awkward filenames, full-blob inspection, binary and symlink
exclusions, initial commits, explicit bypass, custom and legacy hook
delegation, stdin/argv preservation, linked worktrees and recursion rejection.

# Jujutsu (jj) Quick Reference

## Basic Operations

### Initializing a Repository

`jj` can manage a brand-new repo or one that already has a `.git` directory. The **colocated** mode is the most useful for interop — it keeps a real `.git/` directory alongside `.jj/`, so other tools (`gh`, IDE git integrations, GitHub Actions checkout, pre-commit hooks) still work normally.

```bash
# Initialize a brand-new colocated repo in the current directory
jj git init --colocate

# Convert an existing git repo to be jj-managed (run inside the repo)
jj git init --colocate

# Clone an existing remote as a colocated repo (colocation is the default;
# use --no-colocate to disable)
jj git clone --colocate <git-url> <dir>

# Create a jj repo backed by an existing Git repo at a different path
jj git init --git-repo <path-to-git-repo> <name>

# Check or change colocation mode of an existing repo
jj git colocation status
jj git colocation enable
jj git colocation disable
```

> ⚠️ **Set up `.gitignore` BEFORE running `jj git init --colocate`.** `jj` snapshots
> the working copy on every command, and anything not gitignored at init time gets
> swept into the initial change. Cleaning it up afterward is annoying — you have to
> abandon/squash and re-snapshot, and if you've already pushed, the bad blobs live
> in the remote history. Common offenders to ignore first: build output dirs
> (`node_modules/`, `target/`, `build/`, `dist/`), secrets (`.env`, credentials
> files), OS junk (`.DS_Store`, `Thumbs.db`), editor swap/backup files, and large
> binary artifacts.
>
> If you've already done the init without ignoring something, see *Undo an
> Accidental Working-Copy Snapshot* below — the recipe is `.gitignore` the path
> first, then `jj file untrack`.

### Identity & Config

```bash
# Configure identity (jj uses --user instead of git's --global)
jj config set --user user.name "Your Name"
jj config set --user user.email you@example.com

# Edit config by scope
jj config edit --user
jj config edit --repo
jj config edit --workspace
```

### Commits

```bash
# Finalize the current change AND open a new empty change on top.
# This is the right tool for landing a sequence of separate commits.
jj commit -m "Commit message"

# Edit JUST the description of the current change (no finalize, no new change).
# After this, further edits keep modifying the same change.
jj describe -m "New commit message"

# Set the working-copy revision (for amend-style edits,
# prefer `jj new` + `jj squash`)
jj edit @

# Create a new empty change on top of current commit (or a specified revision)
jj new
```

> ⚠️ **Common pitfall**: using `jj describe -m` between push cycles when you
> meant `jj commit -m`. `describe` only renames the current change — subsequent
> edits stack onto the same change, and successive `describe`/push cycles
> sideways-overwrite the same commit on origin under different messages while
> accumulating diff. Looks like N separate commits in your terminal scrollback,
> but only one commit exists in git history. Use `jj commit -m` whenever you
> want the current change to be done and a fresh empty change ready for the
> next feature.

### Viewing Changes
```bash
# Show repository status (similar to git status)
jj status

# View detailed log
jj log

# View last N commits
jj log -n 5

# Show diff of current working copy
jj diff

# Show diff between specific revisions
jj diff --from <rev1> --to <rev2>

# Show diff between a revision and its parent(s)
jj diff -r <rev>
```

### Working Copy & Tracking
```bash
# New files are auto-tracked by default (except ignored files)
# Configure with snapshot.auto-track (example disables auto-track)
jj config set --repo snapshot.auto-track "none()"

# Manually track or untrack paths
jj file track <paths>
jj file untrack <paths>
```

### Branching and Naming Commits

```bash
# List all bookmarks (similar to git branches)
jj bookmark list

# Create a bookmark (similar to git branch)
jj bookmark create <name>

# Point a bookmark at your current work (mirrors git checkout -b <name>)
jj bookmark create <name> -r @

# Create and switch to a bookmark (similar to git checkout -b)
jj bookmark create <name> && jj edit <name>

# Update a bookmark to point to another revision
jj bookmark set <name> <revision>

# Move a bookmark (often used to update a bookmark to point to current working copy)
jj bookmark set <name> @

# Track or inspect remote bookmarks
jj bookmark track <name>@<remote>
jj bookmark list --remote <remote>
```

Bookmarks are jj's branch equivalent; there is no "current" bookmark. Bookmarks do not move when you create new commits, but they follow rewrites.

### Working with GitHub

```bash
# Fetch remote refs/commits and import them into jj
jj git fetch

# Target a specific remote (mirrors git fetch <name>)
jj git fetch --remote <name>

# After fetch, rebase or merge onto the desired remote bookmark
jj rebase -d <bookmark>@<remote>

# Export your current jj view into the underlying Git repo
jj git export

# Push changes to GitHub (defaults to tracked bookmarks)
jj git push

# Push a specific bookmark (mirrors git push origin <branch>)
jj git push -b <bookmark_name>

# Allow a brand-new remote bookmark to be created (like git push --set-upstream)
jj git push -b <bookmark_name> --allow-new

# Push to a specific remote
jj git push --remote <name> -b <bookmark_name>

# After using regular git commands, re-import to update jj's view
jj git import

# Inspect or add remotes
jj git remote list
jj git remote add <name> <url>
```

There is no `jj git pull`; use `jj git fetch` + `jj rebase -d <bookmark>@<remote>` (or merge).

Set default remotes in `.jj/repo/config` so plain `jj git fetch` or `jj git push` pick the expected remote:

```toml
[git]
fetch = "origin"
push = "origin"
```

### Troubleshooting: remotes + detached HEAD

```bash
# jj does NOT use git's remotes unless configured in jj:
jj git remote list
jj git remote add origin <ssh-url>

# If git shows "HEAD (no branch)", reattach:
git switch -c <branch>
# then export jj state into git (if needed)
jj git export
```

Notes:
- In a colocated repo, `jj git push` uses jj's remote list, not git's. Add the remote in jj or set `[git] fetch/push` in `.jj/repo/config`.
- If you already have git remotes, copy the SSH URL from `git remote -v` into `jj git remote add`.

### Keeping jj, Git, and GitHub in Sync

1. Run `jj git fetch` to bring down the latest remote refs.
2. Use `jj rebase -d <bookmark>@<remote>` (or merge) so your commits sit on the desired remote tip.
3. In colocated workspaces, jj auto-imports/exports on every command; in non-colocated workspaces, use `jj git export` after jj changes and `jj git import` after git changes.
4. Push with `jj git push -b <bookmark>` (add `--allow-new` for brand-new remote branches).
5. If you moved refs in Git directly, mirror those moves back into jj with `jj git import`.

## Common Revision Specifiers

- `@` - Current working copy
- `@-` - Parent of current working copy
- `@--` - Grandparent of current working copy
- `<bookmark>@<remote>` - Remote-tracking bookmark (e.g., `main@origin`)
- `<commit_id>` - Specific commit by ID (prefix is enough to be unique)
- `<change_id>` - Change ID (shown at the start of `jj log`, stable across rewrites)
- `<bookmark_name>` - Points to commit with that bookmark

## Common Workflows

### Fix a mistake in the previous commit
```bash
# Create a new change, then squash it into the previous commit
jj new
# ... make changes ...
jj squash --from @ --into @-
```

### Create a new branch and work on it
```bash
# Create a new branch
jj bookmark create feature-branch

# Create a new commit (automatically on the new branch)
jj commit -m "Start work on feature"
```

### Squash commits
```bash
# Squash one revision into another
jj squash --from <rev> --into <target>
```

### Rebase a series of commits
```bash
# Rebase a range of commits onto a target
jj rebase -s <start>..<end> -d <target>
```

## Working with Conflicts

```bash
# View conflicted files
jj status

# Resolve conflicts with merge tool
jj resolve <file_path>

# After resolving, continue with the operation
jj commit -m "Resolved conflicts"
```

## Operation Log (Undo/Redo)

```bash
# Inspect the operation log
jj op log

# Undo/redo the most recent operation(s)
jj undo
jj redo

# Revert or restore a specific operation from the log
jj op revert <operation_id>
jj op restore <operation_id>
```

## Undo an Accidental Working-Copy Snapshot

jj auto-snapshots **all** non-ignored working-copy files into `@` on every
command. Colocating a repo (`jj git init --colocate`) or running any jj command
while build caches / vendored deps / scratch files are still untracked will
pull that junk into your change. Two ways to back it out:

```bash
# BEST for untracked junk: ignore it, then untrack it (files stay on disk).
# `jj file untrack` refuses unless the path is gitignored, so ignore it first.
echo 'some-build-dir/' >> .gitignore
jj file untrack some-build-dir scratch some-cache.bin

# Operation-log rewind: undoes the LAST operation (rebase/squash/describe/etc.).
jj undo                      # revert the most recent op
jj op restore <operation_id> # rewind to a known-good op (see `jj op log`)
```

Caveat: `jj undo` / `jj op restore` alone will **not** keep untracked files out —
the next jj command re-snapshots them. For stray untracked files the durable fix
is always *gitignore + `jj file untrack`* (or delete the files). Tested on jj 0.41.

## Restore and Revert


```bash
# Restore paths from another revision into the working copy
jj restore --from <rev> --into @ <paths>

# Apply the inverse of a revision onto a destination
jj revert -r <rev> -o <dest>
```

## Tips and Tricks

1. jj automatically snapshots your working copy before operations
2. There is no staging area; most `jj` commands snapshot the working copy automatically
3. Use `jj op log` + `jj undo`/`jj redo` or `jj op revert`/`jj op restore` to recover
4. Use `jj abandon` to abandon a revision (use `--retain-bookmarks` if needed)
5. Use descriptive bookmark names for easier navigation
6. `jj git` subcommands provide interop with git repositories
7. `jj log` shows the change ID first, then the commit ID

## Converting Common Git Commands

| Git Command              | Jujutsu Equivalent                 |
|--------------------------|-----------------------------------|
| `git add`                | Automatic with jj (or `jj file track`) |
| `git commit`             | `jj commit -m "message"`           |
| `git commit --amend`     | `jj new` + `jj squash --into @-`    |
| `git checkout branch`    | `jj edit branch_name`              |
| `git branch`             | `jj bookmark list`                 |
| `git branch name`        | `jj bookmark create name`          |
| `git push`               | `jj git push`                      |
| `git pull`               | `jj git fetch` + `jj rebase -d <bookmark>@<remote>` |
| `git log`                | `jj log`                           |
| `git diff`               | `jj diff`                          |
| `git rebase`             | `jj rebase`                        |
| `git reset --hard HEAD~1`| `jj abandon @`                     |
| `git stash`              | Not needed (auto-snapshots)        |

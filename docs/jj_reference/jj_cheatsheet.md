# Jujutsu (jj) Quick Reference

## Basic Operations

### Commits
```bash
# Create a commit (like git commit)
jj commit -m "Commit message"

# Edit the description of the current commit
jj describe -m "New commit message"

# Amend current commit
jj edit @

# Create a new empty change on top of current commit
jj new
```

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
jj diff -r <rev1> -r <rev2>

# Show diff between a revision and its parent
jj diff -r <rev>
```

### Git-friendly Setup

```bash
# Clone an existing Git repo and keep .git accessible for Git tooling too
jj git clone --colocate <git-url> <dir>

# Add jj to an existing Git repo in place
jj git init --colocate

# Configure identity (jj uses --user instead of git's --global)
jj config set --user user.name "Your Name"
jj config set --user user.email you@example.com
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
jj bookmark list --remote
```

Bookmarks are jj's branch equivalent; create or move them before pushing so the matching Git branch exists when you export/push.

### Working with GitHub

```bash
# Fetch remote refs/commits and import them into jj
jj git fetch

# Target a specific remote (mirrors git fetch <name>)
jj git fetch --remote <name>

# After fetch, rebase or merge onto the desired remote bookmark
jj rebase -d @remote/<default_branch>

# Export your current jj view into the underlying Git repo
jj git export

# Push changes to GitHub (defaults to main branch if no bookmark specified)
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

Set default remotes in `.jj/repo/config` so plain `jj git fetch` or `jj git push` pick the expected remote:

```toml
[git]
fetch = "origin"
push = "origin"
```

### Keeping jj, Git, and GitHub in Sync

1. Run `jj git fetch` to bring down the latest remote refs.
2. Use `jj rebase -d @remote/<bookmark>` (or merge) so your commits sit on the desired remote tip.
3. Run `jj git export` whenever you repoint `@` or bookmarks inside jj so the underlying Git repo (and tools like `git status`) see the same commits.
4. Push with `jj git push -b <bookmark>` (add `--allow-new` for brand-new remote branches).
5. If you moved refs in Git directly, mirror those moves back into jj with `jj git import`.

## Common Revision Specifiers

- `@` - Current working copy
- `@-` - Parent of current working copy
- `@--` - Grandparent of current working copy
- `<commit_id>` - Specific commit by ID (prefix is enough to be unique)
- `<bookmark_name>` - Points to commit with that bookmark

## Common Workflows

### Fix a mistake in the previous commit
```bash
# Go back to previous commit
jj edit @-

# Make changes
# ...

# Update commit
jj commit -m "Updated message"
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
# Squash a commit into its parent
jj squash <commit_id>
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

## Tips and Tricks

1. jj automatically snapshots your working copy before operations
2. Use `jj undo` to undo the last operation
3. Use `jj abandon` to abandon a revision
4. Use descriptive bookmark names for easier navigation
5. `jj git` subcommands provide interop with git repositories

## Converting Common Git Commands

| Git Command              | Jujutsu Equivalent                 |
|--------------------------|-----------------------------------|
| `git add`                | Automatic with jj                 |
| `git commit`             | `jj commit -m "message"`           |
| `git commit --amend`     | `jj edit @`                        |
| `git checkout branch`    | `jj edit branch_name`              |
| `git branch`             | `jj bookmark list`                 |
| `git branch name`        | `jj bookmark create name`          |
| `git push`               | `jj git push`                      |
| `git pull`               | `jj git fetch`                     |
| `git log`                | `jj log`                           |
| `git diff`               | `jj diff`                          |
| `git rebase`             | `jj rebase`                        |
| `git reset --hard HEAD~1`| `jj abandon @`                     |
| `git stash`              | Not needed (auto-snapshots)        |

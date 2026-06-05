# Jujutsu (`jj`) Quick Reference (For Users and Agents)

## For Git Users: The Mental-Model Shifts

The command-translation table below is necessary but not sufficient. A few git assumptions don't carry over — internalize these and the rest of `jj` stops looking weird.

**1. No staging area.** Your working copy IS a commit (the `@` commit). Every `jj` command auto-snapshots it. There's no `add` step and no index. When done, `jj commit -m` finalizes it and opens a fresh empty one. To split changes (the `git add -p` workflow), commit everything and then `jj split`.

**2. Commits have two IDs: change_id (stable) and commit_id (mutates).** In git, rewriting (rebase, amend) creates brand-new SHAs and the originals fall into reflog. In `jj`, the `change_id` is a stable identity that persists through rewrites — only the `commit_id` (the Git SHA equivalent) changes. Bookmarks and references survive rebases/squashes by tracking the change_id. `jj evolog` shows every prior commit_id of one change_id.

**3. Rewriting is safe and routine.** Git users learn to fear `rebase -i` and `--force` push. In `jj`, every rewrite is recorded in `jj op log` and undoable with `jj undo` / `jj op restore`. Rewriting a commit in a stack auto-rebases all descendants. You don't plan defensively around it.

**4. Conflicts are first-class state, not blockers.** Git stops the world at a conflict and forces resolution before you proceed. In `jj`, a conflict is a property of a commit — that commit is still valid; you can move it, rebase it, push it, or commit on top of it. You resolve when *you* decide, not when the tool demands.

**5. Bookmarks aren't branches — they're stable pointers.** Git branches advance automatically when you commit. `jj` bookmarks DON'T move when you create new commits; you explicitly `jj bookmark set <name> @` to advance one. There's no "current branch" / HEAD-attached-to-a-ref concept — `@` is the whole story. Conceptually, a bookmark is closer to a movable tag than a git branch.

**6. Two logs, not one.** `jj log` shows the change graph (commits + working copy + relationships). `jj op log` shows repo-level operations (every command that changed state). Git only has the former. The second log is what makes `jj`'s "undo my whole bad day" superpowers possible — `jj op restore <op_id>` rewinds the entire repo to any prior moment.

## Quickstart: Converting Common Git Commands

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
| `git commit --fixup` + `git rebase --autosquash` | `jj absorb` (auto-routes hunks to ancestors) |
| `git reflog` (per-commit only) | `jj evolog -r <change_id>` (per-change predecessor chain) |


## Basic Operations

### Initializing a Repository

`jj` can manage a brand-new repo or one that already has a `.git` directory. The **colocated** mode (which is now the default in `jj 0.41+`) is the most useful for interop — it keeps a real `.git/` directory alongside `.jj/`, so other tools (`gh`, IDE git integrations, GitHub Actions checkout, pre-commit hooks) still work normally.

```bash
# Initialize a brand-new colocated repo in the current directory.
# (--colocate is the default in jj 0.41+; the flag is harmless. Use --no-colocate to opt out.)
jj git init [--colocate]

# Convert an existing git repo to be jj-managed (run inside the repo)
jj git init [--colocate]

# Clone an existing remote as a colocated repo (colocation is the default;
# use --no-colocate to disable)
jj git clone [--colocate] <git-url> <dir>

# Create a jj repo backed by an existing Git repo at a different path
jj git init --git-repo <path-to-git-repo> <name>

# Check or change colocation mode of an existing repo
jj git colocation status
jj git colocation enable
jj git colocation disable
```

> ⚠️ **Set up `.gitignore` BEFORE running `jj git init [--colocate]`.** `jj` snapshots
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
>
> **Agents:** finish each unit of work (tests green, build clean) with `jj commit -m`. Reserve `jj describe -m` for renaming the in-progress change between micro-edits.

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

> **Agents:** spew-mode `jj log` burns context fast. Default to `jj log -n 5 --no-graph` for compact output, or `-T '<template>'` for machine-readable fields — useful templates: `change_id.shortest()`, `commit_id.shortest()`, `description.first_line()`, `bookmarks`, `author.email()`.

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

# Update a bookmark to point to another revision (forward only by default)
jj bookmark set <name> <revision>

# Move a bookmark (often used to update a bookmark to point to current working copy)
# Use --allow-backwards to move a bookmark backwards or sideways:
jj bookmark set <name> @
jj bookmark set <name> <revision> --allow-backwards

# Track or inspect remote bookmarks
jj bookmark track <name> --remote=<remote>
jj bookmark list --remote <remote>
jj bookmark list --all-remotes                # show everything (local + every remote)
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

# Push a specific bookmark (mirrors git push origin <branch>).
# In jj 0.41+, new bookmarks are auto-tracked on push — no --allow-new needed.
# (--allow-new still works but is deprecated; tracking can also be auto-configured via
# remotes.<name>.auto-track-bookmarks.)
jj git push -b <bookmark_name>

# Push a commit by change-id — auto-creates a `push-<changeid>` bookmark.
# Ideal for one-shot WIP / "open a PR for this change" workflows.
jj git push --change @

# Push a new bookmark under an explicit name without creating it locally first
jj git push --named myfeature=@

# Push a commit that has no description yet (otherwise rejected).
# Default: jj refuses to push commits with empty descriptions.
jj git push -b <bookmark_name> --allow-empty-description

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

# If git shows "HEAD (no branch)", see the next section to point HEAD at a
# real branch name. (Avoid `git switch`/`git checkout` in jj-managed repos —
# raw git ops can desync jj's view. Prefer the symref technique below.)
```

### Leaving git on a real branch name (colocated repos)

In a colocated repo jj keeps git's `HEAD` **detached at `@-`** on purpose: that
way stray `git` operations can't accidentally move your bookmarks. The cost is
that anything reading git directly — shell prompts (starship), IDEs, some CI
checkout steps — reports a bare commit hash / "detached HEAD" instead of a
branch name.

To leave git *thinking it's on a branch*, point `HEAD` at the bookmark that
sits on `@-`:

```bash
# Standard way (if raw git is available):
git symbolic-ref HEAD refs/heads/<bookmark>

# If raw git is blocked (e.g. a block-git hook), write the symref file
# directly — this is byte-for-byte what `git symbolic-ref` produces:
printf 'ref: refs/heads/<bookmark>\n' > .git/HEAD
```

Prerequisite: a bookmark must actually point at `@-` (the parent of the empty
working-copy commit). Set one first if needed: `jj bookmark set <name> -r @-`.

**CAVEAT — treat this as an end-of-work tidy step.** Any jj command that *moves
the working copy* (`jj new`, `jj commit`, `jj squash`, `jj rebase`, `jj edit`,
`jj git push`, …) re-detaches `HEAD` at the new `@-`. Read-only commands
(`jj status`, `jj log`, `jj diff`, `jj bookmark list`) leave a symbolic `HEAD`
untouched. So finish all your jj operations first, then set `HEAD` last.

Notes:
- In a colocated repo, `jj git push` uses jj's remote list, not git's. Add the remote in jj or set `[git] fetch/push` in `.jj/repo/config`.
- If you already have git remotes, copy the SSH URL from `git remote -v` into `jj git remote add`.

### Keeping jj, Git, and GitHub in Sync

1. Run `jj git fetch` to bring down the latest remote refs.
2. Use `jj rebase -d <bookmark>@<remote>` (or merge) so your commits sit on the desired remote tip.
3. In colocated workspaces, jj auto-imports/exports on every command; in non-colocated workspaces, use `jj git export` after jj changes and `jj git import` after git changes.
4. Push with `jj git push -b <bookmark>` — new bookmarks are auto-tracked on push in jj 0.41+; for one-shot WIP/PR, `jj git push --change @` auto-creates a `push-<changeid>` bookmark and pushes it.
5. If you moved refs in Git directly, mirror those moves back into jj with `jj git import`.

## Workspaces (jj's "worktrees") vs. Git Worktrees

**jj has no `git worktree` equivalent and does not understand git's worktrees.** `jj git` has no `worktree` subcommand. jj's own multiple-working-copy feature is `jj workspace`:

```bash
jj workspace add <path>      # create an additional working copy (jj's "worktree")
jj workspace list            # list jj workspaces (a raw `git worktree` is INVISIBLE here)
jj workspace forget <name>   # stop tracking a jj workspace
jj workspace root            # path of the current workspace
jj workspace update-stale    # refresh a workspace whose working copy went stale
```

**Gotcha — a raw `git worktree add` is invisible to jj.** It lives only in git's `.git/worktrees/…`; `jj workspace list` won't show it and no jj command can remove it. Claude Code's own worktree isolation (e.g. `~/.claude-worktrees/…`) is git-native too, so cleaning those up is a git-only job:

```bash
# Remove a git worktree jj can't see (git is the ONLY tool that can):
git worktree remove [--force] <path>   # --force if it has uncommitted/redundant changes
git worktree prune                     # tidy stale .git/worktrees entries
# Then delete the leftover branch the jj-native way (keeps jj as source of truth):
jj bookmark delete <name>
jj git export                          # propagate the deletion to git's ref
```

Rule of thumb: for isolated working copies under jj, prefer `jj workspace add` over `git worktree add`. If a git worktree already exists, only git can tear it down — do the worktree mechanics in git, then delete the branch/bookmark via jj.

## Common Revision Specifiers

- `@` - Current working copy
- `@-` - Parent of current working copy
- `@--` - Grandparent of current working copy
- `<bookmark>@<remote>` - Remote-tracking bookmark (e.g., `main@origin`)
- `<commit_id>` - Specific commit by ID (shortest unique prefix is enough — see below)
- `<change_id>` - Change ID (shown at the start of `jj log`, stable across rewrites; **also accepts shortest unique prefix**)
- `<bookmark_name>` - Points to commit with that bookmark

### Shortest-Unique-Prefix IDs

Both `commit_id` and `change_id` accept the **shortest prefix that is currently unique** in the repo. In a small/young repo that's often **1–3 characters**; even huge repos rarely need more than 4–6. `jj log` visually marks the unique prefix vs. the disambiguator: the unique part is rendered brightly (typically magenta for change_id, blue for commit_id) and the rest is dimmed — so a quick glance tells you exactly how many characters you need to copy.

```bash
# Real `jj log` line looks like (color stripped):
#   qpvuntsm  yourname@example.com  2026-06-03 14:22:11  abc123de
#   ^^^^                                                  ^^^^
#   bright change-id prefix          dimmed disambig.    bright commit-id prefix

# Use just the bright part — jj resolves it
jj show qp           # uses change_id "qp..."
jj describe -r abc   # uses commit_id "abc..."
jj rebase -d qp -s xyz
```

When/if a future commit collides with your short prefix, jj refuses with `error: Change ID prefix "qp" is ambiguous` (it does NOT silently pick one). Lengthen the prefix and retry — usually one more character disambiguates.

> **Power tool for AI agents.** Agents handle IDs as strings; the prefix discipline means an agent can pull change IDs from `jj log` output and use them verbatim, without needing to track the full 32-char ID. Pair with `--no-graph` and `-T 'change_id.shortest() ++ "\n"'` to get *just* the shortest prefix per line in machine-readable form:
>
> ```bash
> jj log --no-graph -T 'change_id.shortest() ++ " " ++ description.first_line() ++ "\n"'
> ```

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

### Absorb working-copy changes into the right ancestors

`jj absorb` solves a workflow that's tedious by hand: you make broad fixes across a working stack of commits, then want each fix to land in the *correct* ancestor (not all dumped into the tip). Absorb pattern-matches your working-copy hunks against each ancestor's diff and pushes every unambiguous hunk into the nearest ancestor that already touched those same lines.

```bash
# Push each working-copy hunk into the closest ancestor that already
# touched those same lines. Ambiguous changes stay in @.
jj absorb

# Limit which ancestors are eligible targets
jj absorb --into <revset>

# Choose the source revision (default: @)
jj absorb --from <revset>

# Preview what would move where without applying
jj absorb -p
```

> **Power tool for AI agents.** Agents tend to make broad changes across many files when fixing a class of issue. Instead of threading `jj squash --interactive --from @ --into <ancestor>` per hunk by hand, the agent can make the full edit pass, then `jj absorb` to sort everything into the right commits automatically. Especially useful for: cross-cutting refactors that touch multiple commits in a stack, applying review feedback that spans several layers of work, and de-noising a working copy before code review.
>
> Caveats:
> - Only absorbs **unambiguous** hunks (exactly one ancestor touches those lines). Anything ambiguous stays in `@` — review with `jj diff` afterward.
> - Won't traverse conflicts — clean working tree first (`jj resolve`).
> - Best paired with a stack of small, semantically-distinct commits. A monolithic ancestor will swallow everything.
> - Pair with `jj evolog -p -r <ancestor>` after absorbing to verify each commit's diff is still coherent.

## Working with Conflicts

```bash
# View conflicted files
jj status

# List all conflicts (non-interactive; useful for scripting/agents)
jj resolve --list

# Resolve conflicts with the configured external merge tool (interactive)
jj resolve <file_path>

# Resolve all conflicts non-interactively by always picking one side:
jj resolve --tool :ours      # take side #1 (working copy / "our" side)
jj resolve --tool :theirs    # take side #2 (incoming / "their" side)

# After resolving, continue with the operation
jj commit -m "Resolved conflicts"
```

> **Agents:** `jj resolve` defaults to an external merge tool, but three non-interactive paths exist:
> - `jj resolve --list` to discover conflicts programmatically.
> - `jj resolve --tool :ours` / `--tool :theirs` for the built-in side-pickers when one side is known correct.
> - For nuanced conflicts neither side handles cleanly: edit conflict markers (`<<<<<<<` / `=======` / `>>>>>>>`) directly in the working copy; any subsequent jj command re-snapshots, and once the markers are gone the conflict clears automatically.

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

> **Agents:** if a multi-step rewrite went sideways, `jj op log -n 20` shows everything you did and `jj op restore <op_id>` rewinds the entire repo to that moment. The "I broke it" panic button — coarser than `jj evolog` but covers anything.

## Evolution Log (Per-Change History)

`jj evolog` is the **per-change** counterpart to `jj op log` (which is repo-wide). It shows every prior version of a single change — each snapshot, describe, squash, rebase, abandon, etc. — so you can recover, inspect, or restore content from a specific moment in a commit's history without unwinding the whole repo.

```bash
# Show the predecessor chain of the current change (@)
jj evolog

# Same for a specific change/commit
jj evolog -r <change_id>

# Include patches (diff at each step) for the full forensic view
jj evolog -p

# Linear / no-graph output — easier to parse programmatically
jj evolog --no-graph
```

Recovery recipes:

```bash
# Restore a clobbered commit message from a prior predecessor
jj describe -m "$(jj evolog -r @ -T 'description ++ "\n"' --no-graph | sed -n '2p')"

# Restore file content from a specific predecessor (without changing other files)
jj restore --from <predecessor_id> -r @ <paths>

# Re-run a destructive operation differently:
# 1) jj evolog -p   → find the predecessor that had the right state
# 2) jj op log      → find the operation_id of when it was right
# 3) jj op restore <operation_id>  → rewind the whole repo to that moment
```

> **Power tool for AI agents.** When an agent runs several rewriting operations (squash, rebase, describe, abandon) and you want to know exactly what it touched on a specific commit, `jj evolog -p -r <change_id>` shows the diff at every intermediate step. Combined with `jj restore --from <predecessor>`, you can selectively roll back individual changes to a single commit without disturbing siblings — much finer-grained than `jj op restore`, which rewinds the whole repo state.

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


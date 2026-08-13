# Publishing the collaboration-evidence ledger

The canonical ledger remains in `$HOME/MEMORIES`. Its public history is the
[collaboration-evidence gist](https://gist.github.com/pmarreck/79d51cede20efd07a99bc378a8658b2d),
cloned locally at `$HOME/Code/global_pmarreck_llm_memories` on `yolo`.

Publish deliberately:

```bash
collaboration-ledger publish
```

The command performs one synchronous transaction:

1. Copy the canonical ledger to an ephemeral review file in `$TMPDIR`.
2. Validate its required frontmatter.
3. Reject owner-specific absolute home paths and PEM private-key blocks.
4. Require a clean gist clone containing only the ledger file.
5. Fetch and fast-forward from the public `yolo` branch.
6. Display the complete public-to-review-snapshot diff and its SHA-256.
7. Require the full SHA-256 to be typed back exactly.
8. Confirm the canonical ledger did not change during review.
9. Commit only the reviewed file and push it to the gist.

If pushing fails after the commit, rerun the same command. It verifies that
exactly one local commit is ahead, that it changes only the ledger, and that its
bytes match the newly reviewed digest before retrying the push.

No hook, watcher, timer, daemon, or automatic network publisher is involved.
The gist receives a new ordinary Git commit only when this command completes.

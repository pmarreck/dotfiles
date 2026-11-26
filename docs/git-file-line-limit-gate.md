# Staged source-file line-limit gate

`bin/git-file-line-limit-gate` inspects the staged Git index before commits and
rejects added or changed text source files longer than 500 lines. It deliberately
does not inspect unchanged legacy files. Documentation, configuration, binary
blobs, symlinks, submodules and deletions are outside this source-file policy.

The gate reads staged blobs by object ID. Working-copy content cannot hide or
create a violation. Git command failures and malformed index data fail closed.
The existing explicit per-commit bypass remains loud and is intended only for a
genuinely reasoned single-file design.

## Owner-approved advisory repositories

The gate contains a central `ADVISORY_GITHUB_REPOSITORIES` table in dotfiles.
An entry changes the over-limit verdict from a hard failure to the same strong
split recommendation with exit status zero. Project-local files and environment
variables cannot enroll a repository. The current entry is:

- `pmarreck/validate`

Every future entry requires a separate explicit owner decision and dotfiles
change. The repository identity comes from the exact GitHub `origin` owner/name;
a similarly named directory, fork, other host or project-local marker remains
hard-blocking.

`bin/test/git-file-line-limit-gate_test` exercises real staged indexes and real
composed commits in a disposable repository. It covers the 500/501 boundary,
staged-versus-working-copy authority, exempt types, unchanged legacy sources,
unusual pathnames, canonical validate remotes, spoofed identities, bypass
behavior, repository-hook ordering and Git inspection failures.

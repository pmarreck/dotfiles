# Staged source-file line-limit gate

`bin/git-file-line-limit-gate` inspects the staged Git index before commits and
reports added or changed text source files longer than 500 lines. The temporary
default for all repositories is a strong advisory. It names each over-limit
file and recommends splitting it into testable modules. A line-count advisory
exits zero. Unchanged legacy files, documentation, configuration, binary blobs,
symlinks, submodules and deletions are outside this source-file policy.

Nix files (`.nix`) are exempt by default, including `configuration.nix` and
`flake.nix`. A source file staged alongside a Nix file can still draw an
advisory. Other commit checks still apply to Nix files.

The gate reads staged blobs by object ID. Working-copy content cannot hide or
create a violation. Git command failures and malformed index data fail closed.
The existing explicit per-commit bypass remains loud and is intended only for a
genuinely reasoned single-file design.

## Restoring enforcement

Set `ENFORCE_BY_DEFAULT` to `true` in the gate when the owner restores the hard
limit. In that mode, `ADVISORY_GITHUB_REPOSITORIES` in dotfiles preserves
owner-approved advisory exceptions. Its current entry is `pmarreck/validate`.
Project-local files and environment variables cannot enroll a repository.

Every exception requires a separate explicit owner decision and dotfiles change.
The gate identifies a repository by its exact GitHub `origin` owner and name.

`bin/test/git-file-line-limit-gate_test` exercises real staged indexes and real
composed commits in a disposable repository. It covers both policy modes, the
500/501 boundary, staged-versus-working-copy authority, exempt types, unchanged
legacy sources, unusual pathnames, canonical validate remotes, spoofed
identities, bypass behavior, repository-hook ordering and Git inspection failures.

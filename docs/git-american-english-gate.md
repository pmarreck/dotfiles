# American English commit and PR gates

The shared `pre-commit` and `pre-merge-commit` chain runs
`american-english-check --staged` after the conflict-marker and dependency gates.
LuaJIT selects complete staged regular-file blobs and normalizes ASCII case;
`rg` does fixed-string whole-word matching against the local sourced dictionary,
retaining Unicode word boundaries. Git object reads and searches are batched.
Unstaged edits cannot hide staged violations. Deleted files, symlink targets,
submodules and binary blobs are excluded. No historical commit is rewritten.

Examples include `colour`, `COLOURS`, `colouring`, `neighbours` and
`neighbourhoods`. Identifier component splitting also catches `setColour` and
`background_colour`, without matching arbitrary substrings such as `xcolourx`.
Diagnostics name the path, line, spelling and suggested American replacement.
The gate never automatically edits code or renames external APIs.

The [dictionary provenance](../share/american-english/README.md) describes the
licensed source, selection rules and reproducible generator. Missing tools,
malformed policy and failed reads refuse the check instead of reporting success.

## Intentional exceptions

For a one-off quotation, external API or deliberate locale, use a reason:

```sh
ALLOW_BRITISH_ENGLISH='Preserving a verbatim quotation' git commit -m 'Document the original statement'
ALLOW_BRITISH_ENGLISH='Preserving an upstream API identifier' gh pr create --title 'Fix colour API dispatch' --body-file draft.md
```

The reason must contain at least 12 characters and whitespace, on one line.
`1`, `true` and empty strings are rejected. A successful override prints a warning
and the reason to stderr; it bypasses only this spelling check, not other hooks.
Do not use the override merely to avoid correcting prose. Local hook controls
prevent accidental mistakes; someone able to edit or bypass hooks can evade them.

Persistent exceptions use the staged `.american-english-allowlist`, with one
tab-delimited row per exact repository-relative path, lowercase word and reason:

```text
src/adapter.rs	colour	External API identifier required by upstream
locales/en-GB.json	*	Deliberately requested British English translation
```

`*` exempts that one whole file. There are no path globs or repository-wide word
exemptions. The policy file is configuration, not prose, and is not scanned for
its own listed words. Keep exceptions narrow and review policy changes.

## GitHub CLI

The `bin/gh` wrapper checks `gh pr create` (including `pr new`) and `gh pr edit`
before invoking the next `gh` executable on PATH. It checks explicit title/body
arguments and body files, including stdin (`--body-file -`). Body input is copied
into private scratch and those exact checked bytes are submitted; the source file
is untouched. Normal exit status and metadata-only edits are preserved. Other
commands pass through unchanged.

Creation requires explicit `--title` and `--body` or `--body-file`. Interactive
editing, browser submission, autofill, recovery, templates and attachments can
change prose after a preflight check, so this wrapper refuses those modes unless
the reason-required override is present. Generate a draft first, inspect it,
then supply it explicitly. Unrecognized mutation flags are refused rather than
guessed. Existing PR fields not being edited are not rechecked.

The wrapper does not intercept browser/API/MCP clients, arbitrary gh aliases,
extensions, direct invocation of the underlying binary, PR comments or reviews.
Git hooks also do not inspect PR prose or commit messages. Enforcement depends
on the wrapper preceding the underlying gh executable on PATH and on Git using
the shared hook chain; repository-local hooksPath overrides must delegate to it.

Direct text checking is available as `american-english-check --file draft.md`
or `american-english-check --file - --label 'PR body'` for stdin.

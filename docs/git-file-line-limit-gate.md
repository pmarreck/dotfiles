# Staged source-file line-limit gate

`bin/git-file-line-limit-gate` inspects the staged Git index before commits and
reports added or changed text source files with more than 500 code lines. The
temporary default for all repositories is a strong advisory. It names each
over-limit file and recommends splitting it into testable modules. A line-count
advisory exits zero. Unchanged legacy files, documentation, configuration,
markup, stylesheets, templates, binary blobs, symlinks, submodules and deletions
are outside this source-file policy.

## Only code lines count

Blank lines and comment-only lines, including doc comments and docstrings, are
not counted, so the limit never rewards deleting comments or spacing. A line
with any code on it counts, even with a trailing comment. Each report shows the
excluded lines, for example:

```text
  "src/parser.lua": 512 code lines (limit 500); 230 comment and 140 blank lines not counted
```

`git-file-line-limit-gate --count FILE...` prints the code, comment and blank
counts for any file, tab-separated, followed by its path.

The gate picks comment syntax from the file extension, or from the interpreter
on a `#!` line for scripts without one. It tracks single-line comments, block
comments across lines (nested where the language nests them, such as Rust,
Swift, Elm, Haskell, Lean, Nim, WAT, OCaml and Lisp), and strings, so comment
markers inside strings, multi-line strings, Lua long strings and shell heredocs
stay code. Python and Julia docstrings, Elixir `@doc`/`@moduledoc` and Erlang
`-doc`/`-moduledoc` strings, and the shell's `: <<'END'` comment idiom count as
comments. Covered languages include C, C++, Zig, Rust, Go, JavaScript and
TypeScript, Elixir, Erlang, shell, Lua, Roc, Awk, Lean, Elm, Haskell, Nim,
Python, Julia, WAT and others; see `SYNTAX` in the gate. A file in an unknown
language has only its blank lines excluded, so uncertainty never lowers a
count.

## Exempt files

Documents (Markdown, text, reStructuredText and similar), configuration (Nix,
TOML, YAML, JSON, XML and similar, including `configuration.nix` and
`flake.nix`), and markup, stylesheets and templates (HTML, SVG, CSS, Sass,
Less, Phoenix `.heex`/`.eex`/`.leex`, ERB, Haml, Slim, Handlebars, Mustache,
EJS, Jinja, Liquid, Nunjucks, Twig) are exempt. Components that carry script
logic, such as Svelte and Vue files, are source. A source file staged
alongside an exempt file can still draw an advisory. Other commit checks still
apply to exempt files.

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
500/501 code-line boundary, comment and blank lines that cannot push a file
over the limit, per-language comment fixtures, staged-versus-working-copy
authority, exempt types, unchanged legacy sources, unusual pathnames, canonical
validate remotes, spoofed identities, bypass behavior, repository-hook ordering
and Git inspection failures.

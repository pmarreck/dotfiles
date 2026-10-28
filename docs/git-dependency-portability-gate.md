# Staged dependency portability gate

The shared `pre-commit` and `pre-merge-commit` chain runs three fail-fast checks
before delegating to a repository's own hook:

1. `git-conflict-marker-gate`
2. `git-dependency-portability-gate`
3. `american-english-check --staged` (see [the spelling gate](git-american-english-gate.md))

`git-staged-gates` fixes that order for both the global and dotfiles-local hook
paths. The dependency gate reads index blobs, never the possibly different
working tree. It normally inspects only added, modified, copied, renamed or
type-changed dependency files. A staged `flake.lock`, exception policy or
symlink change causes a bounded rescan of tracked manifests because those
changes can invalidate an unchanged declaration.

## Checked formats

- `Cargo.toml`: `path` and `git` sources in dependency, development,
  build, target, workspace and patch tables. Dotted and quoted keys, inline
  tables, TOML basic/literal strings and Unicode escapes are recognized.
  Multiline dependency values fail closed with an unsupported-syntax error.
  `[lib]` and `[[bin]]` path fields are outside dependency scope.
- `Cargo.lock`: local `file:`, `git+file:` and `path+file:` package sources.
- `.cargo/config` and `.cargo/config.toml`: top-level path overrides plus
  source `directory`, `local-registry` and local `registry` values. Paths are
  resolved from the directory containing `.cargo`, following Cargo's rule.
- `build.zig.zon`: static `.path` and `.url` values inside the
  `.dependencies` object. Dynamic dependency expressions fail closed.
- `flake.nix`: static Nix path literals and source-like `url`, `src` and
  `source` assignments. Comments, ordinary strings and indented strings are
  tokenized separately. Indented-string escapes and nested interpolation
  quoting keep runtime paths inside the string token. Dynamic flake input URLs
  fail closed.
- `flake.lock`: structural JSON inspection rejects path sources and local
  URLs. Remote file fetchers remain valid.

Relative paths resolve from the declaring source boundary and must remain
inside the repository. Their destinations must be represented in the index.
Every staged symlink prefix is resolved from its blob; absolute, outside-root,
cyclic and missing destinations fail. POSIX absolute paths, Windows
drive/UNC paths, home or environment expansion and local file URLs fail.

## Nix-staged source exception

Nix may supply a pinned external source at an in-root path that is deliberately
absent from Git. The only static exception is a tracked staged
`.dependency-portability.json` using this exact versioned form:

```json
{
  "schema": "dependency-portability/v1",
  "nixStaging": [
    {
      "manifest": "build.zig.zon",
      "path": ".deps/engine",
      "input": "engine",
      "staging": "flake.nix"
    }
  ]
}
```

Each record names one exact Cargo/ZON manifest and literal dependency path, one
root flake input, and the tracked regular file defining the staging operation.
No wildcard or directory-wide exception exists. The destination must remain
inside the repository and absent from Git. The staged lock graph must resolve
the named input, including a bounded `follows` path, to a known nonlocal source
with a content hash. Git-like sources also require a full revision. Unknown
source schemas, mutable refs, malformed/cyclic follows targets, symlink
producers and extra policy fields fail.

This policy proves only that an exact declaration has an exact pinned source
and named producer. It cannot prove that programmable Nix code copies the
source into the expected layout. A clean source-bounded Nix build or check,
with sandboxing enabled and no ambient sibling checkout or cache, remains the
independent control for staging behavior and complete source closure.

## Override

An intentional temporary exception requires a conspicuous human-readable
reason:

```sh
ALLOW_NONPORTABLE_DEPENDENCIES='temporary upstream fixture; tracked in issue 42' \
  git commit ...
```

Short boolean values such as `1` are refused. A valid override prints its exact
reason and bypasses only the dependency gate; conflict and repository-local
hooks still run. `--no-verify`, hook replacement and editing the hook remain
ordinary client-side escape routes, so this is an accidental-error control,
not a security boundary.

## Static-analysis boundary

The Cargo and ZON readers implement the dependency-bearing syntax described
above and reject unsupported forms instead of assuming safety. The Nix reader
is a non-evaluating tokenizer, not a Nix interpreter. It does not prove
computed paths, source filters, build-script reads, network behavior or full
derivation closure. The hook scans no history and runs no repository code.

`bin/test/git-dependency-portability-gate_test` creates disposable repositories
and exercises staged/worktree disagreement, parser classifiers, awkward paths,
renames/deletes, symlink invalidation, exact Nix exceptions and real blocked
and successful commits. The dotfiles flake supplies pinned LuaJIT and
`lua-cjson` runtimes for the packaged test.

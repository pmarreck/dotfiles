# dirtree

`dirtree` is a Bash wrapper around [`eza`](https://github.com/eza-community/eza) that produces stateful directory trees. It aims to make it easy for humans—and tooling like LLM pair-programmers—to share a consistent view of a project hierarchy without drowning in noise from build artifacts, vendor bundles, or other clutter.

## Use case

- Capture and persist the “interesting” parts of a repository’s structure by closing noisy directories or hiding file types you rarely need.
- Share tree snapshots that match what you normally see locally, so collaborators (human or AI) have the same mental model of the project layout.
- Switch between a decorated tree (with icons, hyperlinks, colors) and a simplified, glyph-free output that’s LLM-friendly.

## Features

- **Persistent state per directory** via `.dirtree-state` (stored in a concise INI-MA format):
  - Default directory state (`opened`/`closed`).
  - Explicit open/close rules.
  - Show/hide filters for literals and regex patterns.
  - Automatic migration from legacy key/value state.
- **Flexible matching**
  - Regexes operate on full relative paths, enabling scoped rules like `src/.*_test`.
  - Literal paths allow quick toggling of individual files or directories.
- **Runtime toggles**
  - `--show-hidden` temporarily reveals everything hidden by config.
  - Hidden directories/files are counted and summarized after each run (decorated mode uses dim italics; simple mode prints plain text).
- **Decorated vs simple output**
  - Decorated mode keeps eza’s colors, icons, and OSC8 hyperlinks.
  - Simple mode removes ASCII art connectors so LLMs or diff tools can ingest the tree without glyph noise.
  - Auto-simple mode can kick in for non-TTY outputs via `DIRTREE_AUTO_SIMPLE`.
- **CLI conveniences**
  - `--open`, `--close`, `--show`, `--hide` accept multiple values and regexes using the `/pattern/` form.
  - `--default` and `--sort` options to tune depth and ordering.
  - `--test` hook to run the bash test suite.
- **Safety niceties**
  - Number of hidden directories/files logged to stderr so you know what’s filtered out.
  - Conflicting rules (e.g., same path in open/close) surface as errors.
  - Unknown lines in the state file are preserved on rewrite.

## Dependencies

- [`eza`](https://github.com/eza-community/eza) – required for decorated output.
- POSIX-ish shell utilities (`bash`, `find`, `sed`, `grep`, `mktemp`, etc.) that are present on most Unix-likes.

## Getting started

```bash
# Install eza first (example for macOS with Homebrew)
brew install eza

# Put dirtree somewhere on your PATH and mark executable
chmod +x bin/dirtree

# Generate a tree with defaults
dirtree

# Collapse vendor directory and hide .log files
dirtree --close vendor --hide '/\\.log$/'

# Temporarily show everything that is hidden
dirtree --show-hidden
```

State lives in `.dirtree-state` at the root of whatever directory you run `dirtree` inside. Commit or share those files if you want collaborators (or your future self) to inherit the same view.

## Tests

The repository includes bash-based integration tests under `bin/test/dirtree_test`. Run them via:

```bash
bin/test/dirtree_test
```

They cover CLI flags, persistence, migration, hidden summaries, and interaction with the simple/decorated modes.

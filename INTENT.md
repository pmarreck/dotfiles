# Dotfiles Intent

## Purpose and user

This repository keeps Peter Marreck's shell configuration and personal command-line utilities versioned, testable, and reproducibly installable across his machines. Peter is the sole intended user. Agents and other maintainers contribute to the repository but do not expand its product scope.

## Desired outcomes

- A clone at `~/dotfiles` plus `install_dotfiles` establishes the expected home-directory links without manual configuration drift.
- Shell startup, aliases, and commands behave consistently across Peter's active Linux and macOS systems where platform differences permit.
- Small personal utilities remain easy to inspect, test, repair, and replace.
- Configuration history is recoverable, and sensitive information does not enter the public repository.

## Scope and non-goals

The repository owns Peter's shell startup files, aliases, terminal-facing helpers, installation links, and their tests. It may package external tools needed to test those files reproducibly.

It is not a general-purpose dotfiles distribution or a public CLI product. Compatibility work for hypothetical users, localization infrastructure, and unrelated system configuration are outside scope unless Peter explicitly adds them. The repository-wide localization decision is recorded in [RULES.md](RULES.md).

## Constraints and tradeoffs

- Preserve data and keep changes recoverable through Git, backups, or Trash.
- Prefer small, test-driven changes and explicit dependencies.
- Keep personal commands fast enough for interactive shell use.
- Support real host behavior while keeping deterministic, isolated tests wherever the operating-system boundary can be injected.
- Use the existing `master` branch because this repository predates the `yolo` convention.

## Success evidence

Focused tests must prove each changed behavior. The Nix flake's test check is the reproducible full-suite gate, while live-shell checks confirm path, alias, terminal, and host integration that a sandbox cannot establish. [PLAN.md](PLAN.md) records current work and completed verification.

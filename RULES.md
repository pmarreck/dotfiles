# Dotfiles Rules

## Internationalization

- Status: `declined`
- Decision owner: Peter Marreck
- Decided: 2026-07-24 12:19 EDT
- Scope: this personal dotfiles repository and its one-owner helper commands
- Rationale: these tools are not distributed products; adding and maintaining
  localization infrastructure would not currently repay its complexity.

Do not add i18n infrastructure here unless Peter explicitly revisits this
decision.

## Host test environment

- Status: `decided`
- Decision owner: Peter Marreck
- Decided: 2026-10-13 21:16 EDT
- Scope: the host suite run by `./test`
- Rationale: these dotfiles configure Peter's interactive login shell, which is
  not a Nix closure, and Home Manager is deliberately deferred. The host suite
  therefore tests the real host environment and does not re-enter
  `nix develop --ignore-environment`, unlike the fleet default for project
  suites. The sandboxed `nix build .#checks.<system>.test` remains the pure
  check.

Consequence: any tool a dotfiles command calls from PATH must be installed
declaratively on every host (nix-darwin `~/.config/nix`, NixOS host configs in
`nix_machine_configs`) and covered by those repos' contract tests, not only
listed in this flake. Revisit if Home Manager is adopted.

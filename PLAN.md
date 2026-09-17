# dotfiles — TODO / Plans

## Active: live wall-clock `times` command (2026-09-16)

- [x] Reproduce Peter's second live report through the real interactive shell
      startup path: `times COMMAND` still reaches Bash's builtin and prints four
      process-time fields instead of invoking `bin/times`.
  - Curiosity poke: the existing test sources `.aliases` directly with
    `expand_aliases`; prove whether normal startup omits that file, disables
    alias expansion, or later startup code replaces the alias.
  - Completed 2026-09-16 22:38 EDT: the four fields are Bash builtin output.
    Fresh shells already load the override, while Peter's long-lived shell
    predates it. The intended refresh command was an external subprocess and
    sourced nonexistent `bin/aliases.sh`; the replacement test failed 6 of 9
    checks and reproduced `times` falling through to the builtin.
- [x] Repair command resolution with the smallest persistent shell-surface
      change, rerun the focused startup and PTY controls plus both complete
      gates, update dirtree notes, and commit the green bug fix.
  - Curiosity poke: test both a fresh interactive shell and the already-running
    shell upgrade path without relying on command hashing or manual re-sourcing.
  - Completed 2026-09-16 22:45 EDT: `.bashrc` now loads `rehash` as a function
    in the parent shell, and `rehash` sources the real `.aliases` after path and
    environment refresh while restoring the caller's settings. Direct execution
    rejects its former false-success path with the one-time recovery command.
    Ten hermetic refresh checks, all three host startup quadrants, 80 `timed`
    assertions, all 185 host test files, and all 140 hermetic files pass.

- [x] Establish and record the repository's intent from the README, flake,
      rules, current implementation, and Peter's confirmation.
  - Curiosity poke: keep the personal dotfiles boundary explicit so a helper
    change does not silently turn into public-product compatibility work.
  - Completed 2026-09-16 12:50 EDT: `INTENT.md` now records the one-owner
    purpose, cross-host outcomes, scope boundary, constraints, and test evidence.
- [x] Characterize `timed`, then add failing-first tests for invocation as
      `times`, exact local `YYYYMMDDHHMMSS.d` formatting, calendar rollover,
      non-interactive line prefixes, and live PTY output.
  - Curiosity poke: Bash already owns `times` as a builtin, and aliases do not
    preserve their original name in the child process.
  - Completed 2026-09-16 13:00 EDT: the old implementation failed 16 of 60
    assertions; the red cases cover the relative entry point, builtin override,
    fixed epochs around midnight, piped lines, and an `expect` PTY.
- [x] Implement the smallest shared mode switch while preserving `timed` output,
      command exit status, final elapsed-time report, and terminal cleanup.
  - Curiosity poke: derive the calendar fields and fractional digit from one
    clock sample so a second-boundary race cannot produce an impossible stamp.
  - Completed 2026-09-16 13:02 EDT: `bin/times` is a relative symlink, the shell
    alias overrides Bash's builtin through an explicit path, and shared live
    rendering selects elapsed or local wall-clock output from the invoked name.
- [x] Run focused tests, ShellCheck, the complete host suite, and the hermetic
      Nix check; update dirtree notes and commit the known-good unit.
  - Curiosity poke: a regex-only PTY check can accept malformed dates, so pair
    it with fixed-epoch formatter tests.
  - Completed 2026-09-16 13:16 EDT: 60 focused assertions, all 185 host test
    files, and all 140 hermetic test files pass. `timed_test` graduated from the
    hermetic exclusion list. ShellCheck reports no new diagnostic classes or
    counts and two fewer SC2155 findings than `HEAD`.
- [x] Add the accepted `--prefix N` line-filter mode to both commands. Reserve
      exactly N columns, serialize live status and child stdout through one
      renderer, and document that the child sees a pipe. Use a blank gutter
      before the first tick and left-truncate an overlong status with `>`.
  - Curiosity poke: child stderr retains its original channel, while stdout is
    line-buffered; verify the real shared-terminal cursor behavior independently
    through a PTY rather than inferring it from separately captured streams.
  - Completed 2026-09-16 17:49 EDT: the exact-width renderer now owns live
    status and child stdout, preserves stdin and exit status, accumulates partial
    lines across ticks, and retains every newline byte. An independent Expect
    PTY drives a partial line across a timer tick and verifies both aligned rows.
- [x] Run the focused red-green cycle, ShellCheck comparison, complete host
      suite, and hermetic Nix check; update dirtree notes and commit the green
      prefix unit.
  - Curiosity poke: preserve command exit status, unterminated final lines, empty
    lines, and exact width when repeated `--prefix` options or quiet mode apply.
  - Completed 2026-09-16 17:51 EDT: 80 focused assertions, all 185 host test
    files, and all 140 hermetic test files pass. ShellCheck has no new diagnostic
    class or count versus `HEAD`; six old unused-variable findings and one old
    source-follow finding disappeared from the test file.

## Pending: host-selected project binaries (2026-09-16)

- [ ] After the `timed`/`times` work, read the
      `cross-platform-project-build-arch` skill and coordinate the approved
      `.pathconfig` migration without launching a fleet migration.
  - Curiosity poke: preserve portable project scripts and host-selected native
    precedence while removing stale `result/bin` and `zig-out/bin` entries.
- [ ] Add failing-first classifier and startup tests for OS/architecture aliases,
      WSL, foreign-target exclusion, paths with spaces, repeated sourcing, and
      stale PATH entries before changing discovery.
  - Curiosity poke: shell command hashing can retain a removed wrong-platform
    path after the textual PATH value is corrected.

## Active — native Herdr erect-agent-stack (2026-09-10)

- [x] Replace the tmux launcher with native Herdr discovery, workspace reuse
      and unrestricted agent startup. Preserve native conversation IDs in a
      private per-project launch record; never fresh-fallback on failed resume.
- [x] Write isolated failing-first CLI tests for fresh/resume/reuse, ambiguous
      targets, occupied shells, startup failures and read-only previews. Test
      against the live server only without affecting existing agents.
- [x] Update the shared skill and run full host and hermetic tests.
      Keep fleet snapshot/restore tools outside this single-launcher migration.
      Completed 2026-09-10 EDT. Herdr CLI v2 reuses live agents untouched and
      records exact native IDs privately. First adoption requires an explicit
      fresh/continue/resume choice; no missing-record or timeout fresh fallback.
      --note emits only a human notification; trust dialogs require inspection.
      185 host tests and 139 hermetic tests passed, including the launcher test
      now promoted from NOT_HERMETIC. ShellCheck passed. Live dry-run correctly
      planned a new workspace without creating it; a real reuse of corruption_probe
      preserved its pane and native session ID. No new test agents were launched.

## Obsidian GUI alias (2026-09-06)

- [x] Replace the directory-changing `obsidian` alias with a GUI launcher for
      the existing Peter Marreck vault. Linux inherits the desktop environment
      through the user service manager; macOS uses `open -a Obsidian`.
      Curiosity poke: remote shells lack DISPLAY, and opening the app without
      the vault URI can show the vault chooser instead of the intended notes.
- [x] Prove both platform alias dispatches with a failing-first test and launch
      the live Thelio GUI. Completed 2026-09-06 14:42 EDT; all 185 host test
      files passed. Launch confirmation does not establish Sync completion.

## Active — let ffpw select a usable Firefox profile (2026-09-06)

- [x] Remove the `ffpw` alias that injects `--channel nightly`; an explicit
      `ffpw --channel nightly` remains available through the CLI itself.
  - Curiosity poke: prove the sourced alias file succeeds before accepting an
    absent alias, or a syntax/startup failure could make the test pass vacuously.
  - Completed 2026-09-06 11:06 EDT: the isolated source test failed first with
    the exact Nightly alias, then passed after its one-line removal.
- [x] Run the focused alias regression, full host suite, hermetic Nix check, and
      pre-push gate; commit separately from the existing sleep-reminder commit.
  - Curiosity poke: a new shell must inherit the bare executable from PATH, not
    a function or second alias elsewhere in the startup chain.
  - Completed 2026-09-06 11:11 EDT: 184 host test files, 137 hermetic test
    files, and the independent 184-test pre-push gate pass. A fresh login shell
    has no `ffpw` alias and resolves `/home/pmarreck/Code/ffpw/bin/ffpw` first.

## Active — sleep reminders address Peter, not agent work (2026-09-06)

- [x] Clarify the 10 PM and later reminders: gently encourage Peter to rest
      while continuing already-authorized work; retain stop/approval/budget limits.
      Curiosity poke: a late-night classifier called `refuse` contradicts that intent.
- [x] Cover both messages with injected-clock regression tests, update the guide,
      and run the focused/full dotfiles test suites.
      Completed 2026-09-06 09:24 EDT: 67 focused assertions and the full 183-test
      pre-push gate pass. Both local Codex and Claude hooks call this live script.

## Active — cross-host Fastfetch alias (2026-09-04)

- [x] Add one `about='fastfetch'` alias, with a failing-first test that rejects
      duplicate definitions and competing dotfiles commands/functions.
  - Curiosity poke: aliases exist only in interactive shells, so verify a fresh
    shell after deployment rather than treating source text as the final proof.
- [x] Run the focused and complete suites, commit and push only the alias/test
      unit, then verify the installed dotfiles checkout on reachable Nix hosts.
  - Curiosity poke: the repository's pre-push gate is authoritative and must
    not inherit unrelated files from another worktree.
- [x] Replace the generated `.git/hooks/pre-push` adapter with a tracked
      `.githooks/pre-push`, make installation select it through repo-local
      `core.hooksPath`, and activate it on every reachable dotfiles clone.
  - Curiosity poke: Git intentionally does not trust hooks merely because a
    clone contains them, so one explicit local configuration step remains.
  - Completed 2026-09-04 10:18 EDT. Commit `789d28a` passed 183 host tests,
    136 hermetic Nix-source tests, and exact-commit Mechatron CI. Thelio,
    Framework, and Tiki use the tracked hook; Tiki's later unrelated work was
    preserved rather than stashed for a test-only fast-forward.
- [ ] Reconcile the existing dirty, 25-commit-behind M4Max dotfiles checkout,
      then pull the alias and select `.githooks` there without discarding its
      NVM/startup work.
  - Curiosity poke: the Mac edits overlap the same startup files changed when
    Volta was retired, so a blind stash/pull/pop would be a poor merge plan.

## Active — crash-safe agent tmux fleet snapshots (2026-09-02)

- [x] Specify `agent_tmux_sessions snapshot [path]`, `restore [path]`, and
      `shutdown [path]` with failing CLI tests and an injectable tmux/history
      boundary. The default state path must be discoverable, atomic, and safe
      across an unclean reboot.
      Curiosity poke: `shutdown` must snapshot successfully before sending any
      termination input, and a partial shutdown must remain recoverable.
      Completed 2026-09-02 17:01 EDT with 62 deterministic CLI assertions and
      an injected tmux, process, history, clock, and host boundary.
- [x] Snapshot every agent pane's tmux session, pane topology, canonical cwd,
      harness, exact resumable conversation ID, and enough launch metadata to
      restore renamed projects. Exclude ordinary shells unless explicitly
      requested, and never persist API keys or other environment secrets.
      Curiosity poke: one project can intentionally contain multiple harnesses,
      as `romantic_collation` does, while project basenames can collide.
      Completed 2026-09-02 16:59 EDT: live dogfood captured 25 agents across
      24 sessions into private current and previous state files; every ID
      matches the hand-audited recovery manifest and raw argv/env are absent.
- [x] Restore all agents with explicit full-privilege flags, exact IDs, and
      bounded concurrency. Inspect terminal state for trust, summary, login,
      selector, failed-resume, or stale-input gates before reporting success.
      Curiosity poke: a slow direnv activation can make a timeout fallback paste
      a second launch command into an already-running Codex input buffer.
      Completed 2026-09-02 17:01 EDT: startup is batched four at a time, direct
      pane launches avoid shell/direnv input races, existing sessions remain
      untouched, and blocked or unready panes make restore fail explicitly.
- [x] Add Grok Build to `erect-recent-agent-stacks`, preserve the current exact
      session metadata contract, and make `erect-agent-stack` use explicit Grok
      `--always-approve --permission-mode bypassPermissions --sandbox off`
      launch flags.
      Curiosity poke: `--yolo` controls approval behavior, while sandbox choice
      is a separate capability and must not be left to mutable configuration.
      Completed 2026-09-02 16:48 EDT: native Grok `summary.json` histories join
      cross-harness newest-session selection, and launches explicitly set all
      three privilege controls.
- [x] Run focused red-green tests, the complete host suite, and the hermetic Nix
      gate; update dirtree notes, commit the known-good unit, and push the three
      already-ahead commits plus this work only after every gate passes.
      Curiosity poke: tests need isolated tmux sockets and deterministic fixture
      histories so they neither find nor kill Peter's live fleet.
      Completed 2026-09-02 17:05 EDT: 62 focused assertions, 180/180 host test
      files, 133/133 sandboxed test files, and the 180-test pre-push gate pass.
      Commit `694d200` plus the three earlier green commits are on `origin/master`.

## Active — harden both `reformat_spaces_to_tabs` implementations (2026-08-27)

- [x] Define deterministic inference tests for the three most frequent widths,
      no unsafe one-space fallback, total tabbed-versus-spaced line counts,
      ignored whitespace-only records, and mixed tab/space prefixes.
      Curiosity poke: an explicit frequency-tie rule must not depend on Awk
      associative-array order.
      Completed 2026-08-27 18:44 EDT: explicit count-descending/width-ascending
      ranking, top-three cutoff, total-line veto, mixed-prefix sampling, blank
      exclusion, and conservative no-op inference are pinned in both versions.
- [x] Add file-adapter tests for empty, JSON, XML, and dash-leading paths;
      longest-record-bounded streaming; and unique same-directory replacement
      files that cannot overwrite a pre-existing `.new` path.
      Curiosity poke: preserve CRLF bytes, final-newline behavior, permissions,
      backups, and multi-file stdout while removing whole-file buffering.
      Completed 2026-08-27 18:44 EDT: both adapters accept the broadened text
      set and dash-leading relative paths, preserve old byte boundaries, leave
      `.new` sentinels untouched, and remove unique same-directory temps.
- [x] Implement the revised contract in LuaJIT, then apply the same algorithm
      and adapter fixes to the preserved Bash/Awk implementation.
      Curiosity poke: both versions need the same tie-breaking and mixed-prefix
      definitions even though their iteration and I/O primitives differ.
      Completed 2026-08-27 18:44 EDT: LuaJIT now uses a streaming sample pass
      and a streaming copy/rewrite pass; Bash/Awk uses the identical ranked
      inference, total-line rule, and whitespace definition.
- [x] Run independent metamorphic checks, the focused differential matrix, and
      the complete host and hermetic Nix suites.
      Curiosity poke: differential agreement proves parity, so an independent
      property must catch the same defect copied into both implementations.
      Completed 2026-08-27 18:44 EDT: 214 focused checks pass, including
      permutation, replication, idempotence, a 15 MB/64 MiB streaming control,
      and the 84-file parity sweep. The clean host fixture passed the formatter
      plus 165/178 files; 13 unrelated live-environment tests were unavailable.
      The canonical Nix gate passed 217 formatter checks and all 131 files.
- [x] Update dirtree notes, preserve collaboration evidence if warranted, and
      commit the known-good unit.
      Completed 2026-08-27 18:46 EDT: all three dirtree notes describe the
      revised roles. The qualifying collaboration case is frontmatter-validated
      and recoverably staged under `/tmp/rstt-hardening.3kQJzL/`; the canonical
      private ledger and live checkout remain read-only. This green project
      state is the formatter hardening commit unit.

## Active — port `randompass` and `randompassdict` to LuaJIT (2026-08-27)

Locale is used only to choose an American or British spelling corpus. This
does not introduce translated UI, localized aliases, or other i18n
infrastructure; the repository-wide i18n scope decision remains unchanged.

Accepted contract: `randompass` preserves its valid-input CLI and `PWCHARSET` /
`RANDOM_SOURCE` behavior; its broader interface cleanup stays deferred.
`randompassdict` accepts `NUM_WORDS` plus an optional exact `N`, inclusive
`M-N`, or inclusive `M..N` length. Options may appear in any order; later
`--american`/`--british` wins. Native locale territory `US` selects the
American SCOWL corpus, while `C`, `POSIX`, regionless, and other territories
fall back to the current British corpus. `--no-proper-nouns` removes exactly
ASCII `^[A-Z][a-z]`, retaining acronyms and one-letter uppercase words.

- [x] Characterize both Bash implementations, their dictionary source,
      randomness contract, CLI surface, and all current callers before writing
      port code.
      Curiosity poke: determine whether either command is sourced as a function
      and whether tests need an injected deterministic random-byte source.
      Completed 2026-08-27 19:13 EDT: `randompass 10` has one repository caller;
      both commands were sourceable Bash functions with direct-execution shims.
      The British corpus is SCOWL 2020.12.07 level 60, and both generators now
      share a pure, injected u32 rejection-sampling seam.
- [x] Add behavior-preserving port tests for `randompass`. Add `randompassdict`
      tests for inclusive `M-N` and `M..N` ranges, malformed and reversed
      ranges, `--no-proper-nouns`, and explicit
      `--american`/`--british` precedence over locale-derived defaults.
      Curiosity poke: define locale handling for `C`, `POSIX`, unset locales,
      regional English tags, and non-English locales without guessing silently.
      Completed 2026-08-27 19:13 EDT: 36 deterministic `randompass` checks and
      71 `randompassdict` checks cover the ports, set classifiers, real corpora,
      UTF-8, exact arithmetic, and secure-source failure behavior. The former
      statistical uniqueness assertion was removed.
- [x] Port `randompass` to LuaJIT without changing its behavior. Port
      `randompassdict` with a testable pure core and injected adapters for
      dictionary access and randomness; its old separate length arguments may
      break.
      Curiosity poke: inspect the dictionary's actual variant data before
      deciding whether American mode selects entries, maps spellings, or uses a
      separate source.
      Completed 2026-08-27 19:13 EDT: the active commands are standalone LuaJIT
      executables. `randompassdict` selects separate American/British SCOWL
      corpora, accepts the new length grammar, and defaults through the native
      locale. Exact decimal exponentiation replaced the external `calc` call.
- [x] Preserve both original implementations as executable `randompass.bash`
      and `randompassdict.bash` files before replacing the unsuffixed commands.
      Defer any broader `randompass` interface redesign to a later task.
      Curiosity poke: existing callers may execute, source, or resolve these
      names through symlinks, so characterize path behavior before renaming.
      Completed 2026-08-27 19:13 EDT: both bodies match their predecessors
      byte-for-byte after the shebang, retain Bash shebangs, and remain
      sourceable. Their complete source-file SHA-256 values are
      `18a3768278460ea237d15fdfeddb73d36726127b1f2e3c31346d68ba3a45bd40`
      and `98eb74a43f65592eef04705d08d6db7ab503c8b798d3147f410367e5360ac823`.
- [x] Run focused, host, and hermetic Nix gates; update dirtree notes and commit
      each passing unit.
      Curiosity poke: statistical output tests need deterministic controls and
      classifier-set coverage rather than flaky distribution assertions.
      Completed 2026-08-27 19:13 EDT: focused host suites pass 36/36 and 71/71;
      shellcheck, LuaJIT bytecode compilation, and diff checks are clean. Nix
      derivation `j3bw6fj4nb41nbjz8b64hd1snjnw7wk1` passes all 132 hermetic
      test files in 37 seconds. Dirtree notes cover every added file.

## Active — port `reformat_spaces_to_tabs` to LuaJIT (2026-08-26)

- [x] Characterize the hybrid Bash/Awk implementation's tab-width inference,
      transformation boundaries, CLI behavior, backups, and file metadata.
      Curiosity poke: Awk's associative-array iteration order may affect which
      indentation widths become the second and third divisibility samples.
      Completed 2026-08-26 06:22 PM EDT: the characterization pins ascending
      indentation-width traversal, successive frequency leaders, the 8-to-2
      divisor search, strict tab-frequency suppression, and byte-level rewrite
      behavior.
- [x] Add a failing regression matrix before implementation, including
      frequency ties, tab-dominant input, mixed tab/space prefixes, blank and
      unindented lines, incomplete space groups, missing/non-text files, paths
      with spaces, multiple files, options, permissions, and backup collisions.
      Curiosity poke: byte-for-byte output and clean stderr matter as much as
      the inferred tab width, especially when stdout combines several files.
      Completed 2026-08-26 06:22 PM EDT: 63 of 67 checks pass against the old
      executable; the four expected failures require a LuaJIT shebang, the
      preserved `.awk.bash` file, and an implementation independent of Awk.
- [x] Preserve the old executable as `bin/reformat_spaces_to_tabs.awk.bash`,
      then implement `bin/reformat_spaces_to_tabs` as a LuaJIT function and CLI
      without changing observed behavior.
      Curiosity poke: in-place replacement must remain recoverable if a write,
      chmod, or rename fails midway.
      Completed 2026-08-26 06:34 PM EDT: the legacy file is byte-identical to
      `HEAD` at SHA-256 `c28d0cd545e008546934a77878661056f79492bd0137ca84b84161d84bc23a20`;
      the active inference and rewriting functions are LuaJIT and execute no
      Awk.
- [x] Run the focused regression, the legacy differential cases, and the full
      host and hermetic Nix suites; update dirtree notes and commit the known-
      good unit.
      Curiosity poke: the test must prove it executed LuaJIT, rather than pass
      accidentally against the preserved Bash/Awk implementation.
      Completed 2026-08-26 06:34 PM EDT: 102 focused checks pass, including an
      84-file mechanical differential sweep; all 178 host and 131 hermetic Nix
      test files pass. The Nix gate also proves patched store-path shebangs.
- [x] Report algorithm critiques only after the behavior-preserving port, with
      each proposed change scoped to both implementations.
      Curiosity poke: distinguish correctness defects from taste or policy
      changes so later fixes can get their own red/green evidence.
      Completed 2026-08-26 06:34 PM EDT: post-port review identified the
      iteration-order-dependent leader sample, aggressive one-space fallback,
      peak-frequency-only tab veto, broad MIME gate, and predictable `.new`
      sidecar as separate follow-up candidates; none changed in this port.

## Active — retire the dotfiles-owned `glob` copy (2026-08-21)

- [x] Add a repository-ownership regression proving dotfiles contains no
      mutable `glob` implementation while `.pathconfig` still discovers
      project-owned `~/Code/*/bin` commands.
      Completed 2026-08-21 04:23 PM EDT: the six-assertion test failed on all
      four duplicate files and the stale sandbox exclusion before removal,
      then passed without requiring a live standalone checkout.
      Curiosity poke: the test must remain hermetic and cannot require Peter's
      live `~/Code/glob` checkout.
- [x] Remove the old executable, helper, and superseded tests; run the full
      host and Nix gates; verify a fresh interactive shell resolves
      `~/Code/glob/bin/glob`; commit and push.
      Curiosity poke: remove the stale `NOT_HERMETIC` exclusion so the sandbox
      fails if its test inventory drifts.
      Completed 2026-08-21 04:23 PM EDT: the old implementation and tests are
      gone, `glob_test` left `NOT_HERMETIC`, all 178 host and 131 hermetic test
      files pass, and fresh minimal plus login shells resolve the standalone
      source executable. The dotfiles flake pins standalone `glob` at
      `f4d2fba` for reproducible tests and development shells.

## Active — deterministic stream grouping (2026-08-21)

- [x] Define `group_with_count` with failing CLI tests covering bytewise-sorted
      grouping, repeated and whitespace-bearing records, empty records and
      input, clean errors, help/about, and stable JSON output.
      Curiosity poke: the default newline record boundary cannot preserve a
      key containing a newline; document that limit and preserve every other
      byte accepted by Lua strings.
      Completed 2026-08-21 14:40 EDT: the initial suite failed at the missing
      executable with status 127, then all 15 focused assertions passed.
- [x] Implement the minimal LuaJIT filter, install it directly on the existing
      dotfiles PATH under Peter's requested command name, and keep text output
      mechanically parseable as `key<TAB>count`.
      Completed 2026-08-21 14:40 EDT: text and stable ordered JSON modes are
      live through `~/bin/group_with_count`; help documents the newline-key
      boundary and embedded-tab JSON escape hatch.
- [x] Prove the complete inbox pipeline with `glob` negation and `cols -3`, run
      the focused, complete host, and hermetic Nix gates, update dirtree notes,
      then commit and push only the intended files.
      Completed 2026-08-21 14:45 EDT: the live 35-project query returned zero
      from all three stages; 179/179 host test files and 131/131 hermetic Nix
      test files passed. Commit and push evidence follows in Git history.

## Active — Markdown frontmatter reader (2026-08-14)

- [x] Specify the CLI contract with failing tests: Markdown paths with spaces,
  `-`/`@stdin`, BOM and CRLF input, malformed or missing frontmatter, multiple
  files, clean stderr, `--json`, and non-TTY plaintext.
  Curiosity poke: JSON needs one stable shape for both one and many documents;
  partial output on the first malformed file would be unsafe for agents.
  Completed 2026-08-14 14:43 EDT: 56 focused assertions cover the input,
  extraction, mode-precedence, body-exclusion, and clean-error contracts.
- [x] Implement `bin/frontmatter` in LuaJIT with a pure extraction/rendering
  core and the existing `cjson` dependency. Parse new `---json` records and
  expose old `---` records as opaque legacy text rather than implementing YAML.
  Curiosity poke: a home-directory script must not silently depend on Lua
  modules that exist only in one interactive shell's `LUA_PATH`.
  Completed 2026-08-14 14:43 EDT: the existing LuaJIT+cjson environment is the
  only runtime; no YAML parser or host reconfiguration was added.
- [x] Render through `glow`, then `bat`, only when stdout is interactive; show
  Peter the real compact and Markdown-table output, update dirtree notes, and
  run the focused plus complete host/Nix suites.
  Curiosity poke: `NO_COLOR`, `TERM=dumb`, `--simple`, and redirected output
  must all produce escape-free plaintext.
  Completed 2026-08-14 14:43 EDT: compact redirected output, renderer-neutral
  `--markdown`, and the live tmux TTY path were inspected; all 177 host test
  files and the hermetic Nix check pass.

## Completed — fleet repository readiness and Mechatron status (2026-08-14)

- [x] Add red/green classifier-set tests for Mechatron configuration: require
  the canonical badge near the top of `README.md`, recognize the stable
  `mechatron` identity without coupling to one Tailscale hostname, and avoid
  accepting prose mentions or unrelated badges.
	Curiosity poke: README badge detection and runnable CI configuration are
	distinct facts; the report must not silently equate one with the other.
	Completed 2026-08-14 15:10 EDT: pure set tests accept the canonical
	repository-specific endpoint badge within the first 40 README lines and
	reject prose, late badges, nested documents, and other-repository badges.
- [x] Carry configured projects' latest Mechatron state into the cached network
  record and report `PASSING`, `FAILING`, `BUILDING`, or explicit unknown using
  the existing machine API/cache rather than launching builds.
	Curiosity poke: a green historical job for an older commit must not describe
	an unbuilt current HEAD as green.
	Completed 2026-08-14 15:10 EDT: HEAD-filtered log and queue queries now
	distinguish passing, failing, building, queued, not-run, and unknown states;
	absent CI configuration causes no provider call.
- [x] Collect README and LICENSE presence locally, identify license type only
  from mechanical signatures or provider metadata, and measure primary
  language through GitHub's API with a deterministic local-tool fallback.
  Carry these repository-intrinsic values forward when the activity fingerprint
  is unchanged instead of rescanning quiet repositories.
	Curiosity poke: generated/vendor trees can dominate byte counts, while a
	missing or ambiguous license must stay `unknown` rather than be guessed.
	Completed 2026-08-14 15:10 EDT: bounded root-file inspection feeds GitHub
	license/language metadata with a declared Tokei fallback; intrinsic facts
	carry with cache-v4 until HEAD or the bounded profile changes.
- [x] Add these facts to the structured snapshot, normal report table, and
  `Repos Requiring Special Attention`; preserve cached values on skipped or
  failed network probes and run focused, complete host, and hermetic Nix gates.
	Curiosity poke: missing README/LICENSE and failed CI are actionable, but an
	intentionally private/non-GitHub repository may require distinct wording.
	Completed 2026-08-14 15:10 EDT: readiness and special-attention projections
	are live-verified; Lua lint is clean, all 178 host test files pass, and the
	hermetic Nix flake check passes all 129 included tests.
- [x] Probe each quiet GitHub origin weekly, plus the parent for forks, so
  commits pushed from another machine invalidate carried repository metadata.
  Curiosity poke: a local HEAD fingerprint proves only this checkout is quiet;
  it says nothing about the shared remote.
  Completed 2026-08-14 15:21 EDT: injected-clock scheduler and offline provider
  fixtures prove unchanged origin/parent timestamps carry the prior observation
  while either change causes a full refresh. All 178 host tests and the
  hermetic Nix check pass.

## Urgent — identify GNOME “Device memory nearly full” warning (2026-08-14)

- [x] Identify the live pressure category and whether “device memory” means GPU VRAM,
  system RAM/swap, or filesystem capacity; capture current consumers and kernel
  evidence before changing state. Curiosity poke: the warning may disappear as
  allocations move, so process and journal timestamps matter.
  Completed 2026-08-14 13:08 EDT: all live capacity categories are safe (GPU
  1.5/12 GiB, 89 GiB RAM available, 10.4 GiB VRAM free, filesystems at most
  57%); GNOME retained neither sender nor text after dismissal, so the exact
  transient source remains unprovable without a notification tap on recurrence.
- [x] Apply the smallest reversible mitigation if pressure remains dangerous,
  then verify headroom without killing Peter's active agents or sessions.
  Completed 2026-08-14 13:08 EDT: no mitigation was justified; swap traffic is
  idle, pools are healthy, and no NVIDIA Xid, kernel OOM, or allocation errors
  occurred in the warning window.

## Active — visible, demand-sensitive fleet report (2026-08-14)

- [x] Publish each saved fleet report atomically to
  `$HOME/Documents/Fleet Status.md` while retaining the machine-readable state
  under XDG state. Curiosity poke: publication must never expose partial bytes
  or make a failed collection replace the last known-good report.
  Completed 2026-08-14 12:50 EDT: exact-byte publication and safe atomic
  replacement pass focused tests; the existing report was copied into Documents.
- [x] Replace the provisional global viewed-or-weekly collection gate with
  per-repository scheduling: locally active repos and forks whose upstream was
  active within seven days receive daily network checks; quiet repos receive a
  lightweight weekly upstream probe; unchecked metadata carries forward.
  Curiosity poke: a dormant fork cannot reveal fresh upstream activity without
  some probe, and dirty working-tree activity has no commit timestamp.
  Completed 2026-08-14 13:27 EDT: an injected-clock scheduler now selects
  `full`, `probe`, or `carry` per repository; provider failures retain the last
  complete observation and its original check time.
- [x] Decide whether the existing canonical JSON snapshot plus per-repository
  cache can provide deterministic carry-forward, or whether an append-only
  NDJSON event journal adds a concrete recovery/audit property. Curiosity poke:
  NDJSON is good history but poor mutable state; derived reports must never
  depend on replaying an unbounded log.
  Completed 2026-08-14 13:27 EDT: canonical current/previous snapshots and
  independently timestamped per-repository caches already provide deterministic
  carry-forward and recovery; NDJSON adds no required property, so it was not
  added.
- [x] Add a leading `Repos Requiring Special Attention` report section whose
  pure classifiers name the measured reason: severe fork drift by commit count
  or time since synchronization, large uncommitted file sets, Git worktrees
  idle for more than seven days, and inboxes with more than one message or a
  message older than one day. Curiosity poke: every threshold needs a named,
  test-injected constant; missing provider timestamps and file ages must be
  `unknown`, never silently clean.
  Completed 2026-08-14 13:27 EDT: pure classifier-set tests cover all exact
  boundaries; the leading Markdown table states each repository's measured
  trigger and partially collected local facts remain explicit unknown risks.
- [x] Extend the structured snapshot only where those classifiers need facts
  not currently collected: last fork synchronization evidence, per-worktree
  activity, and inbox count/oldest age. Curiosity poke: file mtime is mutable;
  prefer durable message metadata when present and document the fallback.
  Completed 2026-08-14 13:27 EDT: snapshots now retain GitHub merge-base time,
  linked-worktree commit ages, and direct inbox count/oldest mtime; the mtime
  fallback and merge-base proxy are documented.
- [x] Prove the revised scheduler and carried-forward values red/green, remove
  the superseded global gating code/tests/docs, run the complete host and Nix
  suites, update dirtree notes, activate the user service, and commit without
  disturbing unrelated worktree changes.
  Completed 2026-08-14 13:44 EDT: focused suites cover 162 assertions after a
  live-report check exposed and fixed duplicate linked-worktree ownership. All
  176 host test files and the hermetic Nix check pass; the enabled timer is
  active, a 166-repository cache-v3 baseline completed, and the verified
  Documents report's atime was restored so agent inspection does not count as
  Peter reading it.

## Active — guarded public collaboration ledger (2026-08-13)

- [x] Preserve the existing public gist as a normal local Git clone on `yolo`
  at `$HOME/Code/global_pmarreck_llm_memories`; keep unreviewed candidates
  outside its object graph. Completed 2026-08-13 11:23 EDT.
- [x] Add failing classifier and state-transition tests for absolute home-path
  rejection, full-diff review, exact-digest confirmation, publish retry, and
  allowed-file enforcement. Curiosity poke: an interrupted push can leave one
  reviewed local commit ahead of the gist and must be safely retryable.
  Completed 2026-08-13 11:38 EDT: 32 focused cases pass, including a forced
  pre-push failure and retry of the preserved reviewed commit.
- [x] Add one cross-platform `collaboration-ledger publish` command that validates,
  shows the complete diff, requires the exact SHA-256, commits, and pushes. No
  hook, watcher, timer, daemon, or persistent candidate is warranted. Completed
  2026-08-13 11:38 EDT: all 174 host test files and the hermetic Nix flake check
  pass; the real ledger and clean gist clone pass non-publishing preflight.

## Active — canonical PATH export gate (2026-08-06)

- [x] Add a tracked-source test that fails on every active `export PATH`
  command outside the explicitly allowed canonical export in `.pathconfig`.
  Prove the gate fails on the current Volta installer residue before removing
  that residue. Curiosity poke: comments, documentation, test fixtures, alternate
  assignment syntax, and multiple commands on one line must not make the
  classifier vacuous or noisy. Completed 2026-08-06 10:21 EDT: the new
  `path_export_policy_test` first failed on 22 commands and now permits only
  `.pathconfig`'s single bare export; synthetic classifier controls cover direct,
  bare, grouped, append, comment, quoted-prose, and similarly named cases.
- [x] Purge obsolete Volta environment and PATH declarations, update startup
  expectations, run focused and complete suites, document the gate, and commit
  only this known-good unit without disturbing existing worktree changes.
  Completed 2026-08-06 10:21 EDT: all five Volta remnants are gone; 19 other
  raw test/Nix exports became ordinary assignments that retain PATH's inherited
  export attribute. All 17 focused tests, the 173-file host suite, and the
  125-file hermetic Nix suite pass.

## Active — align Bash and Lua truthiness semantics (2026-08-06)

- [x] Add a failing Lua classifier-set regression proving that unset/`nil` and
  the documented explicit opt-out tokens are falsey, while every other string,
  including `""` and `"none"`, is truthy. Keep Lua Boolean and numeric inputs
  typed rather than forcing them through string rules.
  Curiosity poke: cross-language parity applies to representable shell strings;
  Lua's `false` and numeric `0` have no distinct Bash-variable types.
  Completed 2026-08-06 12:04 EDT: the 23-case Lua set first failed on `""` and
  `"none"`, then passed after Lua adopted Bash's string rules while preserving
  typed Boolean and numeric behavior.
- [x] Align `truthy.lua`, clarify the set-empty versus unset contract in Bash
  and Lua documentation, run focused and complete host/Nix gates, update
  dirtree notes, and commit without touching concurrent worktree changes.
  Completed 2026-08-06 12:04 EDT: help now separates legal-name validation
  from the Boolean domain and maps valid setness, falsey tokens, and predicate
  statuses. A five-member invalid-name set first failed after an incorrect
  silent-falsey implementation, then proved both predicates loudly return 2
  without evaluating malformed identifiers. Final host and Nix gates pass
  173/173 and 125/125.
- [x] Draft Peter a tweet-sized explanation of why set-empty is truthy for
  delivery after the implementation is committed.
  Curiosity poke: explain the useful Bash state distinction without implying
  that ordinary empty-string comparison can distinguish unset from set-empty.
  Completed 2026-08-06 12:04 EDT with a 257-character draft.

## Queued — identify the pipe-script approval tool (2026-08-06)

- [x] Find the existing `~/dotfiles/bin` command intended to sit between a
  downloaded installer and `sh`, verify its actual safety and invocation, and
  report the remembered name. Curiosity poke: approval must occur after the
  complete input is buffered; streaming bytes onward before approval cannot
  prevent partial execution. Completed 2026-08-06 10:21 EDT: the command is
  `confirm`, and it buffers all stdin before approval. Its executable currently
  defines the function without invoking it, so repair remains separate work
  before using it in an installer pipeline.
- [ ] Repair `confirm`'s executable entry point under TDD and verify that denial
  emits zero stdout bytes while approval emits the complete buffered script.
  Curiosity poke: interruption, empty input, downloader failure, temporary-file
  cleanup, and a downstream shell that starts immediately all need fail-closed
  behavior.

## Active — one Codex installation and updater (2026-08-04)

- [x] Replace the npm-only `update_codex` alias with the standalone CLI's
  native updater, then remove the redundant npm installation and make the PATH
  launcher share Remote Control's `packages/standalone/current` release.
  Curiosity poke: the one-time cutover must not remove the currently running
  agent before the standalone launcher is installed and verified.
  Completed 2026-08-04 22:05 EDT: removed the user-prefix npm package, installed
  the standalone launcher at `~/.local/bin/codex`, and verified that PATH and
  both live Remote Control processes resolve to standalone 0.146.0.
- [x] Prove the old alias fails the single-install contract, make the focused
  test pass, validate the complete suite, update dirtree notes, and commit only
  the updater unit without touching the active `repeat` work.
  Completed 2026-08-04 22:08 EDT: focused test failed twice before the alias
  change, then passed 3/3; ShellCheck is clean and the full host suite passes
  all 172 test files.

## Queued — Baldur's Gate 3 Proton startup failure (2026-08-04)

- [ ] Reproduce BG3's failure to load under Proton tomorrow, capture the Steam
  launch command, selected compatibility tool, Proton log, GPU/driver state,
  game-filesystem mount, and recent crash evidence before changing anything.
  Curiosity poke: distinguish launcher failure, DX11/Vulkan translation,
  filesystem permissions, stale prefix/shader cache, mods, and GPU pressure;
  preserve saves and the Proton prefix until the failing layer is identified.

## Active — repeat compound commands and shorten the push gate (2026-08-04)

- [x] Reproduce `repeat 10 -- 'echo ... | randomz --choose'` running only once,
  then make the quoted compound command execute exactly once per requested
  iteration while preserving existing argv-style repetition.
  Curiosity poke: `--` must distinguish one shell command string from a literal
  executable argument without silently changing quoting, exit, or stdin rules.
  Completed 2026-08-04 22:04 EDT: the regression first failed by treating the
  pipeline as an executable name three times; `--` now selects an isolated Bash
  command string, while calls without `--` preserve exact argv execution. The
  supplied `randomz` pipeline produced ten output lines in a live check.
- [x] Measure the current pre-push suite by per-test wall time, test Peter's
  disk-I/O and parallelism hypotheses, and shorten the gate without reducing
  the 171-test count, weakening skip detection, or hiding failures.
  Curiosity poke: the runner already defaults to eight jobs, so total latency
  may be a longest-test critical path or shared-resource contention rather than
  missing parallel execution.
  Completed 2026-08-05 21:54 EDT: deterministic classifier fixtures and
  in-process trimming reduced `histogram_test` from 27.59s to 3.85s alone;
  `shell_startup_time_test` now keeps one real tmux/login-shell smoke by default
  while retaining explicit multi-sample mode. A same-worktree comparison
  measured 32.96s at 16 workers versus 41.05s at 8, so the bounded default is
  now 16. Two final 172-test host gates passed in 34.58s and 34.80s, 21.6–22.1%
  below Peter's 44.396s push measurement without reducing the test count.
- [x] Repair the deterministic `warhammer_quote_test` blocker exposed by the
  faster parallel gate: inject endpoint selections, assert the current
  `random` range contract, and reject the formerly accepted `nil!` output.
  Curiosity poke: both endpoints must remain reachable when the quote corpus
  grows, without a probabilistic uniqueness assertion or shared `/tmp` file.
  Completed 2026-08-05 21:54 EDT: the new endpoint regression first observed
  two invalid `random 1 193` calls and two `nil!` outputs, then passed after the
  executable adopted the current single-range syntax, `random 1-193`.
- [x] Run focused red/green tests and final complete host and Nix suites, update
  documentation and dirtree notes, then commit each known-good unit.
  Completed 2026-08-05 21:54 EDT: Bash syntax and all focused suites pass; the
  host suite passes 172/172 and the hermetic Nix suite passes 124/124.

## Queued — `show` Markdown classification regression (2026-08-05)

- [x] Reproduce `show zig-build-pattern.md` being classified as Bash with a
  failing classifier/CLI regression, then make Markdown files route to the
  Markdown renderer without weakening shebang-based detection for extensionless
  scripts.
  Curiosity poke: extension, MIME/type output, shebang, and content heuristics
  need an explicit precedence so Markdown fenced Bash cannot become a script.
  Completed 2026-08-05 22:02 EDT: the classifier set first reported the fenced
  executable fixture as `bash`, then passed with explicit final-extension
  precedence for `.md`, `.MD`, multi-dot `.md`, and `.markdown`; extensionless
  Bash and POSIX scripts remain `bash` and `sh` controls. Peter's actual file
  now reports `md` and "Markdown document".
- [x] Run focused and complete suites, update documentation and dirtree notes,
  then commit the known-good classifier fix.
  Completed 2026-08-05 22:02 EDT: Bash syntax and the focused 15-test suite
  pass; the host suite passes 172/172 in 35.07s and the hermetic Nix suite
  passes 124/124.

## Active — current-directory tmux session shorthand (2026-08-04)

- [x] Make `session .` resolve `.` to the current directory basename for both
  creating and rejoining a tmux session; preserve literal names and the
  no-argument `default` behavior.
  Curiosity poke: a directory basename containing spaces must remain one exact
  tmux session name in both the inside- and outside-tmux paths.
  Completed 2026-08-04 17:27 EDT using the logical `$PWD` basename, with
  deterministic coverage for both tmux contexts and a basename containing
  spaces.
- [x] Prove the missing behavior with a failing focused regression, implement
  the smallest fix, run the focused and complete suites, update dirtree notes,
  and commit the known-good unit.
  Completed 2026-08-04 17:27 EDT: the focused test failed on both literal-dot
  calls before the fix, then passed; the host suite passed 171/171 and the Nix
  sandbox suite passed 123/123.

## Active — cryptographically sound `randompassdict` (2026-08-04)

- [x] Reproduce the pool-cardinality, transformed-output, exact-count, and
  invalid-argument defects with failing CLI tests before changing behavior.
  Curiosity poke: dictionary-line identities are not password outcomes when
  duplicate entries or shell text transformations collapse them.
  Completed 2026-08-04 13:38 EDT with seven independently failing security
  regressions plus a failing help/about contract.
- [x] Make selection uniform over unique, unambiguous dictionary words using a
  cryptographically secure OS random source; report exact combinations and
  entropy bits without floating-point integer conversion.
  Curiosity poke: dependency injection for deterministic tests must not create
  a quiet production switch to predictable randomness.
  Completed 2026-08-04 13:40 EDT with fixed `/dev/urandom`, no ambient entropy
  override, literal output joining, deduplication, and exact `bc` arithmetic.
- [x] Run the focused test red/green, then the complete raw and Nix suites;
  update `dirtree` notes and commit only a fully green unit.
  Completed 2026-08-04 13:47 EDT: Bash syntax and ShellCheck clean, focused
  16/16, raw-host 171/171, and hermetic Nix 123/123. The PTY run also exposed
  and fixed `shell_startup_test`'s stopped-process timeout hang.

## Active — recent agent fleet resurrection (2026-08-03)

- [x] Reproduce and fix `erect-agent-stack` timing out on a live Codex 0.146
  pane whose current chrome no longer contains the older readiness strings.
  The trust prompt must still take precedence over process-based readiness.
  Completed 2026-08-03 14:57 EDT with process-aware readiness after a failing
  regression reproduced the 120-second false timeout and fallback paste.
- [x] Add `erect-recent-agent-stacks`, defaulting to conversations active in
  the previous 72 hours. Select the newest main Claude/Codex conversation per
  canonical project directory, exclude subagents, skip missing directories,
  and invoke the existing idempotent launcher with bounded concurrency.
  Completed 2026-08-03 14:57 EDT; the live run restored or reused 20 sessions.
- [x] Provide deterministic `--since`, pure `--dry-run`, `--json`, help/about,
  spaced-path, duplicate-session, cross-backend, and missing-directory tests.
  Keep timestamp selection based on transcript records rather than file mtime.
  Completed 2026-08-03 14:57 EDT with 17 deterministic assertions, including
  renamed-session reuse so `Einstein` is not duplicated as `Code`.
- [x] Run focused red/green tests, the complete suite, update dirtree notes,
  commit and push the known-good unit.
  Completed 2026-08-03 15:03 EDT: raw suite 171/171, hermetic Nix suite
  123/123, implementation commit `016a02e` pushed and independently matched to
  `origin/master`, and exact-commit Mechatron CI passed in 17 seconds.

## Active — nightly fleet status report, all tiers (2026-07-28)

- [x] Port `bin/datetimestamp` from Bash to LuaJIT with a native FFI
  (completed 2026-07-28 07:20 PM EDT):
  high-resolution clock, exactly nine fractional digits, local time by default,
  an explicit `--utc` form carrying a `Z` UTC designator, and
  `-n`/`--nanoseconds-since-epoch` exact-integer output. Epoch integers are
  timezone-independent, so `--utc` intentionally has no effect in `-n` mode.
  Calendar precision is selectable with `--seconds`, `--millis`, `--micros`,
  and `--nanos` (plus their unabbreviated aliases); `--no-decimal` removes the
  fractional separator. These calendar-only switches intentionally do not
  change the explicitly nanosecond epoch-integer mode.
  Preserve existing formatting switches and add deterministic
  CLI/timezone/error-path coverage; rerun focused, raw-host, hermetic, push,
  and exact-CI gates.
  Keep the LuaJIT executable entirely self-contained at `bin/datetimestamp`
  (no project-library imports), and retain the executable former implementation
  as `bin/datetimestamp-bash` during migration.
  - Curiosity poke: POSIX `timespec`, Windows `FILETIME`, timezone conversion,
    fractional truncation, and second rollover must not leak platform-specific
    assumptions into the pure formatter.
- [x] Refactor `fleet-status` into a bold hexagonal design selected by Peter
  (completed 2026-07-28 05:00 PM EDT):
  keep `fleet_status` as the stable facade/schema while extracting pure
  rendering, local Git collection, JSON/state persistence, pure lock parsers,
  provider adapters, and network/cache orchestration behind explicit ports.
  Preserve CLI behavior, public functions, canonical JSON, and approved
  rendered bytes; rerun focused, raw-host, hermetic, push, and exact-CI gates.
  - Curiosity poke: Lua module boundaries can accidentally turn dependency
    injection into globals or create require cycles; boundary tests must prove
    dependency direction and adapter substitution before moving behavior.
- [x] Restore a completely green repository suite: independently reproduce and
  resolve `executables_test`, `getfile_test`, and `shadows_test`, regardless of
  whether the fleet-status changes caused them; 164/167 is not releasable.
  - Curiosity poke: parallel full-suite execution may reveal shared environment
    or fixture coupling that an independently green test hides, so verify both
    focused and canonical parallel runs.
  Completed 2026-07-28 13:27 EDT: deterministic fixtures and the real shadows
  alias fix restored 167/167 locally; the independent hermetic Nix gate passes
  all 118 in-sandbox tests.
- [x] Ship Tier 1 first and independently: build `bin/fleet-status` in LuaJIT
  with collector → JSON → pure-renderer architecture, defaulting to `~/Code`
  with repeatable `--root`.
  Completed 2026-07-28 12:28 EDT: canonical, versioned JSON feeds pure
  one-line and Markdown renderers; LuaJIT+CJSON is declared through Nix.
  - Curiosity poke: JSON must remain extensible for later network-backed tiers
    without making current local-only consumers depend on absent fields.
- [x] TDD the one-line renderer first: name guilty repositories, truncate with
  `+N more`, support full state, and emit the delta from the previous run by
  default; add terminal-readable Markdown rendering.
  - Curiosity poke: distinguish newly risky, resolved, and materially changed
    risks so a delta cannot hide a repo merely because the category count stayed
    constant.
  Completed 2026-07-28 12:18 EDT: six scalar/golden assertions cover
  full/delta/truncation/quiet/canonical output; Peter visually approved the
  exact Markdown before it became an assertion.
- [x] TDD the collector over sets of temporary Git repositories: separate
  staged/modified/untracked counts; distinguish cosmetic detached HEAD from
  commits reachable from HEAD but no branch; collect per-branch ahead/behind,
  no-remote, stash count, branch, HEAD SHA, and last-commit date.
  - Curiosity poke: orphan detection must consider every local branch, including
    a branch whose tip is a descendant of detached HEAD, without mistaking tags
    or remote-tracking refs for local branches.
  Completed 2026-07-28 12:27 EDT: eleven real-repository assertions cover the
  safe/risky detached classifier, every branch, dirty/no-remote sets, stash and
  identity metadata, spaced paths, and nested-vendor exclusion. The live
  regression reduced scope from 199 recursive working trees to 156 fleet
  projects and runtime from ~3.5 minutes to 15 seconds.
- [x] Persist current/previous JSON and rendered Markdown idempotently at a
  documented path; keep `--tier 1` fast.
  - Curiosity poke: interrupted collection must not overwrite the last known-good
    snapshot used as the next run's comparison oracle.
  Completed 2026-07-28 12:20 EDT: twenty assertions cover atomic rotation,
  first/full/delta/no-change output, Markdown publication, alternate state
  directories, and read-only `--no-save`.
- [x] Rename `bin/get_all_git_stati` to `bin/get-all-git-stati`, preserving a
  compatibility route only if repository/fleet references require it; add
  `--root` with `~/Code` default.
  Completed 2026-07-28 11:34 EDT: no callers existed outside the command's own
  dotfiles tests, so no violation-preserving shim was needed; repeatable roots,
  spaced paths, default scope, help, and about are covered 8/8.
- [x] Add a set-classifier test enforcing hyphenated executable names across
  `bin/`, backed by a committed, reasoned allowlist for deliberate legacy
  exceptions.
  Completed 2026-07-28 11:34 EDT: the exact set gate failed first on only
  `get_all_git_stati`, then passed after its rename; the frozen legacy baseline
  prevents new underscore-named top-level executables.
  - Curiosity poke: test executable files, not every sourced identifier/helper;
    the existing tree has many underscore-named legacy executables, so migration
    scope and explicit grandfathering must be mechanically visible.
- [x] Run focused tests after every red/green slice, then the complete
  `bin/run_test_suite`; keep the suite floor at least 160, update docs/dirtree
  notes, inspect stray files, and commit the known-good Tier 1 unit on `master`
  before beginning network tiers.
  - Focused Tier-1 suites green: renderer 6, collector 11, persistence 20,
    nightly 14, plus the approved Markdown golden output.
  - Live report: 156 project repos; 13 unpushed; 27 detached (24 cosmetic-safe,
    3 orphaned: MazeWarsVT100, deadcells_save_editor, entropy_shield); 5
    no-remote. Linux timer enabled/active; next run 2026-07-29 03:27 EDT.
  Completed 2026-07-28 12:30 EDT: all 166 local test files and the hermetic
  `checks.x86_64-linux.test` Nix derivation pass.
- [x] Tier 2 (local): report every branch's ahead/behind state, branches with no
  upstream, and last-commit staleness.
  - Curiosity poke: an unconfigured upstream is distinct from a configured
    upstream whose ref is unavailable; preserve both states in JSON.
  Completed 2026-07-28 12:34 EDT: `--tier 2` marks the tier independently and
  records configured/missing/unknown upstream state plus Git-derived epoch,
  ISO timestamp, and integer age-in-days for every repository and branch.
- [x] Tier 3 (network): discover fork parents with `gh repo view ... --json
  parent`, compare default branches, and distinguish merely behind from
  diverged; fixture the `ollama` yolo/main stale-branch failure class.
  - Curiosity poke: many forks have no `upstream` remote, and GitHub API
    reachability must not be mistaken for Git object availability locally.
  Completed 2026-07-28 12:40 EDT: the injected `gh` fixture discovers the
  parent independently of local remotes and preserves both ahead and behind
  counts as a distinct `diverged` relation.
- [x] Tier 4 (network): report pinned-input drift separately from fork drift;
  cover every `flake.lock` input first, then `build.zig.zon`, Cargo, npm, and
  pnpm locks where present, retaining commits-stale and days-stale separately.
  - Curiosity poke: lock formats identify sources differently and may pin
    immutable archives without a meaningful moving head; return `unknown`
    instead of inventing comparability.
  Completed 2026-07-28 12:40 EDT: offline fixtures cover every requested lock
  ecosystem; direct registry versions and GitHub commits use separate
  comparators, and unrecognized/invalid sources remain `unknown`.
- [x] Tier 5: record the last Mechatron Prime result per repo and explicitly
  flag missing `.mechatron-prime/targets` manifests.
  Completed 2026-07-28 12:40 EDT: read-only `mechatron-ci log --json` results
  and manifest presence are independent JSON values.
- [x] Make network failures/rate limits healthy `unknown` values, add TTL
  caching and configurable bounded concurrency, then make `--all` the nightly
  default while keeping the one-liner limited to immediate human action.
  Completed 2026-07-28 12:40 EDT: 17 offline assertions cover partial tier
  health, clean provider failures, warm/disabled TTL behavior, per-repository
  cache identity, and exact `xargs -P` concurrency propagation. The nightly
  service now invokes `--all`; explicit `--tier 1` remains fast.
- [x] Remediate the independent fleet-status milestone review before release.
  Completed 2026-07-28 13:26 EDT: local Git failure states, local-input cache
  fingerprints, positive/short-negative provider query
  deduplication/deadlines/schema validation,
  real-fleet lock variants, terminal sanitization, and publication locking all
  failed first in regression tests and now pass. The remaining module split is
  recorded in `CODE_REVIEW.md` as a Peter-choice refactor, not a correctness
  waiver.
- [x] Wire the Linux systemd user timer for the all-tier nightly run and
  document the macOS `launchd` equivalent; run the complete suite and live fleet
  report, audit artifacts, commit, and reply to Einstein with green SHA(s).
  Completed 2026-07-28 13:36 EDT: timer enabled/active for the next 03:16 EDT
  run; the live 156-repository refresh completed in 2m42s and named 13
  unpushed, 2 orphaned, 5 no-remote, 70 modified, 5 staged, 139 untracked, and
  6 stashed repositories. Final gates are 167/167 local and 118/118 hermetic;
  durable Einstein reply follows the known-green commit.

## Active — shell helper argument correctness (2026-07-27)

- [ ] ACTION REQUIRED (Peter) — `nixos-rebuild switch` on thelio to actually
  drop volta. The config edit is made and evaluates clean, but I deliberately
  did NOT rebuild: `/etc/nixos` has uncommitted in-flight changes to
  `configuration.nix`, `hardware-configuration.nix`, `flake.lock` and several
  `mechatron-prime/` files from other work, and a switch would apply all of them
  together. My edit is two lines in
  `system76_thelio_nixos/configuration.nix`: drop `volta`, and `nodejs_24` →
  `nodejs` (unversioned, so it rides nixpkgs' default forward instead of sitting
  at 24 forever; `nodejs_latest` is 26.5.0 if the bleeding edge is wanted).
  Backup of the pre-edit file is in this session's scratchpad.
- [x] CCBC — Peter named the "Country/Community Boundary Conflict": Nix is the
  country, language communities value ease-of-use over strict determinism, and
  the treaty is that Nix owns everything up to the project boundary while the
  community owns dependency resolution inside it. Decided 2026-08-01 15:40 EDT.
  - Resolution in one line: **Nix replaces the version managers; the
    community's package managers stay.** nvm/volta/rustup/asdf/pyenv all work by
    global shim name capture; pnpm/cargo/mix/uv all work project-local from a
    hash-pinned lock.
  - Node policy (Peter's call): Nix supplies one global node, ride the current
    default; pnpm owns `node_modules`; `pnpm add -g` is acceptable for global
    CLIs with project-specific overrides where they conflict; bun stays as a
    runtime and `bun build --compile` target, not as the package manager.
  - Rust policy (proposed, not yet applied anywhere): drop rustup, take the
    toolchain from `fenix`/`rust-overlay` honoring `rust-toolchain.toml`; cargo
    owns resolution; nixpkgs first for Rust CLIs since it tracks them well, so
    `cargo install` is rarely justified; `crane` for release/CI builds.
  - Falsification flags that make a procedural reproduction script real rather
    than aspirational: `cargo build --locked`, `pnpm install --frozen-lockfile`,
    `mix deps.get --check-locked`, each run from a clean checkout in CI.
  - Recorded as a shared memory: "Language ecosystem tools may cache globally
    but must never capture global command names".
- [ ] OPEN — `compare_dirs_test` refused a push once (2026-08-01 02:38 EDT) and
  has not reproduced since: 40 runs in isolation, 64 under 8-way concurrency,
  and 4 full suites, all green. Its scratch dirs are `mktemp -d` (no collision)
  and its mtime assertions use fixed `touch -t` stamps (not load-sensitive), so
  neither obvious mechanism fits. Left open deliberately rather than dismissed
  as flake. The gate now preserves its report, so the next occurrence arrives
  with evidence attached — that was the actual blocker, and it is fixed.
- [ ] `~/.local/share/Trash/rm-safe-log` is a DIRECTORY of 34,844 files (178M),
  one per deletion, and only grows. It was the real source of the "40,208
  entries" count — the trash proper held 4,922. Not deleted: it is rm_safe's
  record, not trash, and removing it is Peter's call. Unbounded per-item log
  growth looks like an rm_safe design issue (rotation or a single append-only
  log), and lives in `~/Code/rm_safe`.
- [x] Empty the trash (Peter, 2026-08-01 02:34 EDT). 4,922 entries: 4,908 from
  `/tmp` (test scratch dirs) and 14 from `~/Code`, all of them `nix build`
  result symlinks or files inside git repos. Manifest written to
  `~/trash-manifest-20260801-023249.txt` before deleting. `gio trash` returns 0
  again on a supported mount; killing `gvfsd-trash` had already stopped the
  hang.
- [x] Move the Grok Build installer's `export PATH=...:$PATH` out of `.bashrc`
  and into `.pathconfig`'s `PATH_ADDITIONS`, next to the other vendor-installed
  AI agent CLI; the completion sourcing stays in `.bashrc` alongside the other
  completions. Installer-appended PATH lines run *after* `.pathconfig` has built
  PATH declaratively, so they escape its ordering and dedup rules entirely.
  Completed 2026-08-01 02:40 EDT.
  - Same pattern still present for volta: `.bashrc` exports `$VOLTA_HOME/bin`
    onto PATH while `.pathconfig` already declares `$HOME/.volta/bin`, so it is
    the one genuine duplicate entry in the built PATH. `VOLTA_HOME` itself is a
    real env var and must stay. Not touched — separate from the grok request.
- [x] Keep the pre-push-gate report when the push is refused. It was deleted on
  exit, so a refusal destroyed the only explanation of why. Completed
  2026-08-01 02:46 EDT.
- [ ] DECISION NEEDED — `~/.local/share/Trash` holds 40,208 entries and wedged
  `gvfsd-trash` hard enough that every `rm` on the machine blocked forever
  (`rm` → `rm_safe` → `gio trash`, which has no timeout at `rm-safe:1025`).
  Killing `gvfsd-trash` unblocked it; `gio trash` now fails fast and rm-safe
  falls back to its manual path. Two things to decide, neither of them mine:
  - Pruning the trash destroys recoverability, so it needs Peter's say-so.
  - The test suite trashes its own `$TMPDIR` scratch dirs, which is both the
    source of the 40k entries and a cross-filesystem copy (/tmp → /home) of
    data that was created seconds earlier. Tests deleting their own scratch
    dirs arguably want real `rm`.
  - Upstream fix regardless: `rm_safe` should bound the `gio trash` call
    (`timeout 5 gio trash …`) so a wedged desktop daemon can never hang every
    `rm` on the box. Lives in `~/Code/rm_safe`, not here.
- [x] Stop `show <url>` from then reporting the url as undefined. After handing
  the word to a browser, `show` fell through to the name lookups, warned
  `'example.com' is undefined` and returned 1 for a command that had done
  exactly what was asked. Completed 2026-08-01 02:05 EDT.
  - Curiosity poke (kept): the obvious fix — an early `return` from the url
    branch — would silently swallow every argument after the url, so the
    regression asserts `show <url> <name>` still handles the trailing name.
- [x] Make `rule30` locale-independent. Under `LC_ALL=C` it emitted rows a third
  of the requested width (WIDTH=7 gave 7 *bytes* = 5 glyphs), because bash
  slices `${s:i:1}` by character under UTF-8 and by byte under C, and the live
  automaton state was held as the three-byte `█`. Now the automaton runs on
  one-byte ASCII and the glyph is substituted only at the output boundary.
  Completed 2026-08-01 02:07 EDT.
  - This is the interesting one: the old width assertion used awk's `length()`,
    which *also* counts bytes under C, so the test and the code shared the same
    wrong assumption and the two errors cancelled. The bug was invisible until
    the measurement was made locale-independent.
- [x] Measure characters rather than bytes in `hr_test` (`wc -m` counts bytes
  under `LC_ALL=C`). Counting codepoints by deleting UTF-8 continuation bytes
  needs no locale to be installed — `C.UTF-8` is glibc-only and these dotfiles
  run on macOS too. Completed 2026-08-01 02:04 EDT.
- [x] Sweep the suite for locale-dependent tests by running the whole thing
  under `LC_ALL=C` as well as the ambient UTF-8 locale, rather than grepping for
  `sort`. The grep would have missed both `hr_test` and `rule30_test`, neither
  of which sorts anything. 168/168 under both. Completed 2026-08-01 02:09 EDT.
  - Worth keeping: a periodic two-locale run is a cheap metamorphic control
    over the whole suite. Not wired into CI — the Nix sandbox already runs
    under C, so hermetic tests get that half for free.
- [x] Stop `show README.md` from launching a web browser. `is_web_url` matched the
  bare string and `.md` is Moldova's ccTLD; `.sh` (Saint Helena), `.pl` (Poland),
  `.ai` (Anguilla), `.io` and `.it` are the same trap, covering a large share of
  the filenames anyone actually types. Added `should_open_as_web_url`, split from
  `is_web_url` and kept pure — the caller supplies the existence fact — so both
  branches are testable without a filesystem. Completed 2026-07-31 21:40 EDT.
  - Curiosity poke (kept): an explicit `http(s)://` scheme must outrank the
    filesystem, or a stray directory named `https:` could shadow a real URL.
    Also probes with `-L` as well as `-e`: a dangling symlink named `notes.md`
    is still not a website.
  - Curiosity poke (rejected): probing the disk inside `is_web_url` itself. It
    is shorter, but it makes the predicate impure and untestable without
    fixtures, and `is_web_url` answers a question about syntax — not about
    which of two readings the user meant.
  - Anti-vacuity control: the identical strings must still route to the browser
    when absent from disk, so a "fix" that merely stopped recognizing bare
    domains fails the sensitivity set.
- [x] Pin `LC_ALL=C` on the `sort -u` assertions in `datetimestamp_test`. glibc's
  `en_US.UTF-8` collation ignores case and orders `clock_gettime` first, C
  collation orders `GetSystemTimePreciseAsFileTime` first, so the file passed in
  the Nix sandbox (no `LANG`) and failed on every interactive host — which is how
  it reached master red. Completed 2026-07-31 21:36 EDT.
  - Curiosity poke: worth sweeping the suite for other `sort` calls compared
    against hardcoded literals; this one was found only by tripping over it.
- [x] Remove inbox notes whose work is already landed using `rm-safe`; retain the
  then-unresolved PageUp/PageDown and `session` notes until their work is handled.
  Completed 2026-07-27 16:15 EDT; eight handled/superseded notes moved to the
  recoverable trash.
  - Curiosity poke: both assignment and completion notes for the same landed unit
    are obsolete, while a superseded design note is removable only after its
    replacement is evidenced in the repository.
- [x] Make `edit "path with spaces"` pass the quoted path to the selected editor
  as exactly one argument; preserve the complete argument vector for legitimate
  multi-file editing. Add the regression red-first, run the focused and canonical
  suites, update dirtree notes, and commit the known-good unit.
  Completed 2026-07-27 16:18 EDT: the regression failed 3/5 before the fix and
  passes 5/5 afterward; ShellCheck found no new warnings and all 160 repository
  test files pass.
  - Curiosity poke: directory/file/function/script classification should inspect
    only the first argument, but the eventual editor invocation must not discard
    or split any later arguments.
- [x] Repair the pending `session` regression reported 2026-07-26: outside tmux,
  `new-session -A` must create-and-attach (`-AD`, not detached `-Ad`), with a
  persistent attach-contract regression test before implementation.
  Completed 2026-07-27 19:59 EDT in `c9daedf`: the three attach-contract
  assertions failed first against lowercase `-d`, then all 160 test files
  passed with uppercase `-D`.

## Active — suite gating (2026-07-25)

- [x] Fix `erect-agent-stack_test` racing tmux session startup; it passed solo and
  failed 9/12 concurrently. 60/60 green after. 2026-07-25.
- [x] Parallelize `bin/run_test_suite`: 225.8s → ~35s, reported in discovery order
  so the output stays diff-stable. 2026-07-25.
- [x] `flake.nix` + `.mechatron-prime/targets`: hermetic `checks.x86_64-linux.test`
  turns a standing "target-manifest missing" red into a real gate. 106 of 155 run
  in the sandbox; the other 49 are listed with reasons in `bin/test/NOT_HERMETIC`
  and printed by the check. 2026-07-25.
- [x] Pre-push gate (`bin/pre-push-gate` + `bin/install-git-hooks`) demanding a
  VALID pass: test-count floor, skip allowlist, positive success evidence.
  2026-07-25.
  - Curiosity poke: bash truncates a child's exit status mod 256, so `exit 256`
    is indistinguishable from success — which is exactly why the runner caps its
    summed status at 255 and why the gate keys on positive evidence.
- [x] Rebuild the Steam/Proton process classifier on executable paths rather than
  argv, split pure classifier / enumeration / killing, and give the killer a
  `--dry-run`. 2026-07-26 21:30 EDT.
  - Measured against a live wedged Darktide launch, the old argv heuristic missed
    11 of 20 true positives (every Wine helper, plus the game process itself,
    whose argv is `S:\...\Darktide.exe`) and matched 4 innocent processes —
    including the shell invoking the killer.
  - Curiosity poke that paid off twice: every Claude agent's `/proc/pid/exe`
    resolves to `.../claude-code/bin/claude.exe`, so keying the Wine rule on the
    EXE basename rather than `comm` would have killed the whole fleet — the same
    outcome as the reverted environment-based version, by a different door. And a
    candidate `/nix/store/*-steam-*` argv rule was rejected after it matched the
    diagnostic shell that was testing for it.
  - `-s` is ALWAYS false on procfs (st_size is 0 even with content); it silently
    turned one live assertion into a vacuous pass reporting "0 Wine processes"
    while 12 were running. Read the content, never stat it.
- [ ] Decide whether to test every commit in the outgoing range (≤5, in a detached
  temp worktree) rather than just the tip. Mechatron judges each pushed commit
  against its exact-commit manifest, so a red middle commit surfaces as a real
  FAIL row even when the tip is green. Currently the gate tests the working tree.
- [ ] Graduate tests off `NOT_HERMETIC`. The largest group only needs sibling
  ~/Code repos (printable-binary, rm-safe) added as flake inputs.
- [ ] Migrate the 9 legacy memories still in `~/.claude/projects/*/memory/` into
  `~/MEMORIES` via the `memories` skill (another agent's migration is unfinished).

## Active — code-review remediation (2026-07-24/25)

Driven by `CODE_REVIEW.md` (6-reviewer audit). Wave 1 + the nix-PATH bug are done.

- [x] **`.pathconfig` destroyed every interactive `nix shell`/`nix develop` PATH
  injection** (reported by Einstein 2026-07-25, independently reproduced).
  `ORIG_PATH` is exported+readonly and captured only-if-unset, so a child shell
  inherited the parent's PRE-injection snapshot and `PATH="$ORIG_PATH"` deleted
  the nix entry. Non-interactive `nix develop -c` never sources `.pathconfig`,
  which masked it; direnv survived only because its hook re-applies PATH after.
  Fix = option B: classify `foreign = PATH − ORIG_PATH − PATH_ADDITIONS` and
  re-apply at the front (kept bash-3.2 safe for the macOS bootstrap path); also
  dropped `readonly ORIG_PATH` so the documented re-capture actually works.
  New `bin/test/pathconfig_foreign_path_test` (8 assertions, set-based classifier
  + offline e2e `nix shell` control) — RED first, then green. Completed
  2026-07-25 09:2x EDT.
  - Curiosity poke: `readonly` on an *exported* variable is the real footgun —
    it makes a stale inherited snapshot unrecoverable in the child that needs it.
- [x] Hook-lifecycle fixes (`bin/apply-hooks`): `unset __MCFLY_LOADED` before
  mcfly init (its once-guard made every `.bashrc` re-source silently DROP mcfly
  → history stopped recording); guard the starship PS0 timing magic against
  unbounded accumulation (one extra `starship time` subprocess per re-source);
  removed `__wezterm_osc7_home` (ran last every precmd, clobbering cwd with
  `$HOME` → new tabs/splits opened in `$HOME`). Stub `apply-hooks_test` replaced
  with a real 2-assertion regression test; both assertions proven non-vacuous by
  neutering each fix (mcfly→0×, PS0→2×). 2026-07-24.
- [x] Deleted stale duplicate runner `bin/dotfiles_test` (sourced instead of
  exec'd tests, uncapped exit sum >255 wrapping, re-ran failures, no self-test).
  `bin/run_test_suite` is the canonical one-command gate (154 tests, capped exit,
  self-tested). Deleted the dead SED block in `.bash_profile` (result discarded
  12 lines later; AWK detector preserved). 2026-07-24.
- [ ] Wave 2 (remaining): fail-open guards (`.profile:15`, `.envconfig:3`),
  `timeout` alias grouping (`.aliases:195`), dead LLM-detect regex (`.bashrc:71`,
  `rg --fixed-strings` vs BRE `\|`), readonly re-declare guard (`.envconfig:298`),
  inverted awk warning, `claude/codex.bash` empty-path guard, `/usr/bin/script`
  (`.aliases:106`), `ARCHFLAGS` (`.bashrc:178`), 🔒 `~/Code/*/bin` PATH-shadowing.
- [ ] Wave 3: `${EDIT}` → `${EDIT:-}` across 38 sites / 17 files (`set -u` abort).
- [ ] Wave 4: decide + execute `.shellenv` (orphaned half-finished refactor —
  finish+wire then delete live duplicates, or delete). NOTE: changes login-shell
  load order on BOTH OSes; only Linux is testable from here.

## Active — Claude updater correctness (started 2026-07-24)

- [x] Repair `update_claude` so it updates the PATH-winning npm-global
  installation and explicitly authorizes only Anthropic's native-binary
  postinstall hook.
  - Curiosity poke: an apparently successful global install can update a
    shadowed prefix and leave the invoked executable stale.
  Completed 2026-07-24 13:00 EDT: the ordinary `claude` resolution now reports
  2.1.218, its installed executable is the expected hard link to Anthropic's
  matching native package, and the focused three-assertion regression is green.

- [x] Supersede the npm-global updater with Claude Code's native self-update.
  The npm approach above turned out to CAUSE a dual install: `~/.npmrc` sets
  `prefix=$HOME/.local`, the same prefix the native installer owns, so
  `npm install -g @anthropic-ai/claude-code` overwrote the native launcher at
  `~/.local/bin/claude`. `claude update` then warned "Multiple installations
  found" + "Configuration mismatch" and updated the npm copy instead.
  - Curiosity poke: a half-finished native update leaves a ZERO-BYTE version
    file (`~/.local/share/claude/versions/2.1.220` was 0 bytes) that still reads
    as an installed version to the detector — size, not mere presence, is the
    real health check.
  Completed 2026-07-25 17:15 EDT: reinstalled the native build
  (`claude install latest --force`), removed the npm-global package (needs an
  explicit `--prefix`, and it deletes `~/.local/bin/claude` on the way out — the
  native launcher symlink must be recreated afterward), and repointed
  `upgrade_claude` at `command claude update`. `claude doctor` reports "No
  installation issues found" (native 2.1.220, config method native), the alias
  was verified behaviorally in an interactive shell, and the four-assertion
  regression is green (154/155 dotfiles test files pass; the lone failure,
  `block-attribution_test`, is unrelated — see below).

- [ ] Restore the missing `~/.claude/hooks/` on framework-nixos. Both
  `block-attribution/block-attribution.sh` (fails `block-attribution_test`) and
  `block-git/block-git.sh` (the jj-only guard, so raw `git` is NOT blocked on
  this box) are absent here though the canonical brief assumes them.

## Active — cross-platform GPU observability (started 2026-07-24)

- [x] Add `gpuhogs`: a user-invoked Linux/macOS GPU-process snapshot command
  with Linux NVIDIA (`nvidia-smi pmon`), Linux AMD/Intel (`nvtop --snapshot`),
  and privileged macOS (`powermetrics --show-process-gpu`) adapters feeding one
  normalized renderer; include JSON and interactive `nvtop`.
  - Curiosity poke: distinguish GPU-active processes, CPU-hot processes that
    retain GPU contexts, and merely resident contexts—VRAM ownership alone does
    not prove current contention.
- [x] Add `gpuhogs` to the aggregate `hogs` alias and cover the alias as a set
  so a future edit cannot silently drop any member of the observability family.
  Completed 2026-07-24 12:27 EDT: 32 focused tests and all 152 dotfiles test
  files pass; the macOS command surface was also checked live on Peter's Mac.
- [ ] Remove `diskhogs`' unconditional sudo requirement: provide the strongest
  useful unprivileged per-process view each OS permits, while reserving
  privileged all-user visibility for an explicit mode or on-demand collector.
  - Curiosity poke: Linux may expose same-user `/proc/<pid>/io` counters while
    macOS may require a narrowly privileged sampler for process attribution;
    do not pretend device-wide I/O is per-process evidence.

## Backlog (PARKED — revenue work comes first) — mechanically gate `--help` against the parser

**Peter's theory, 2026-07-27:** `--help` should be derived from something
co-located with the functionality (scraped comments in interpreted languages,
generated at build time in compiled ones) so that "documented but not done" and
"done but not documented" become hard to express. He already did the
co-location half in `ixnay` — help lives beside each subcommand's parsing and is
scraped on the fly — but it is not *enforced*.

**Why this is on the list at all:** on 2026-07-27 `bin/pre-push-gate` documented
a `--check-only` flag in `_help()` that had **no branch** in its
`case "${1:-}"`. The flag was silently accepted, did nothing, and its own test
suite used it while believing it was in check-only mode. Real divergence, in a
gate whose whole job is refusing invalid states.

**Prior art (two camps):**

- *Parser from help*: `docopt` — the usage text IS the grammar, so an
  undocumented flag cannot exist. Ports for Python/Rust/Go/C/bash.
- *Help from code*: Rust `clap` derive (`///` doc comments → help at compile
  time), Go `cobra` (Short/Long on the command struct), Python `click`
  (decorators + docstrings). Zig `comptime` over a declaration struct gets the
  same at build time. `help2man` runs it backwards (scrape `--help` → man page).
  Newer: `usage` (jdx) — one spec file emits parser + docs + completions.

**The refinement worth keeping:** co-location alone is not enough. A comment
adjacent to the code can still lie, because comments are not executed. The
property that actually holds is **single source of truth** — one declaration
from which both the help text and the parse branch are derived, so documenting
a flag *is* implementing its parse path.

**And note the failure mode that bit us is the harder one:** `--check-only` was
not *rejected*, it was **accepted and inert**. A check of "does the documented
flag error?" would have passed, wrongly.

**Proposed gate (MFIC-shaped, cheap):** a shared test helper
`assert_help_matches_parser <cmd>` that:

1. extracts the flag set from `--help` output;
2. extracts the flag set from the parser (bash: the `case` arms; clap/cobra:
   reflection is free);
3. **asserts set equality in BOTH directions** — catching documented-but-unparsed
   and parsed-but-undocumented;
4. optional strongest rung: exercise each documented flag and assert it changes
   observable behavior, catching accepted-but-inert.

Step 3 alone is ~10 lines of bash and would have caught `--check-only`
statically. Because the canonical brief already mandates `-h/--help` and
`--about` on every CLI, this could become a fleet-wide standard that sits
alongside the existing test-count floor and allowlisted-skips checks — turning a
convention enforced by discipline into one enforced by the suite.

**First step when unparked:** run the helper against the existing dotfiles CLIs
and count the divergences. That number is the argument for adopting it fleet-wide.

## Backlog — resurrect Peter's historical iTunes preferences/playlists

- [ ] Recover every historically starred/liked track and the contents/order of
  old playlists from `/mnt/Fileserver/Music/iTunes/iTunes Music/`, including
  Apple's old malformed/nonconforming XML metadata rather than relying only on
  present audio filenames.
- [ ] Inventory every candidate iTunes library/playlist metadata file, preserve
  originals read-only, and build a tolerant parser/repair pipeline with
  regression fixtures for each concrete XML violation encountered.
- [ ] Reconcile duplicate library snapshots and stable track identifiers without
  erasing historical evidence; retain which library/playlist asserted each
  like, star, membership, order, rating, and last-known file location.
- [ ] Produce a human-readable Markdown document plus structured JSON/CSV
  exports suitable for recreating the recovered collections in Spotify,
  SoundCloud, Apple Music, or later migration tooling.
  - Curiosity poke: “ever liked” may be encoded through ratings, loved/disliked
    flags, smart-playlist predicates, or playlist membership depending on the
    iTunes era; treat them as distinct provenance-bearing signals before
    deciding which ones belong in the final union.

## Active — collation / listing thread (started 2026-07-23)

Additive to the already-shipped fun_intro/rg/sessions work; established goals stand.

- [x] `glob`: order matches by **code-point** (`LC_ALL=C`), locale-independent —
  consistent across display + command mode, matching ripgrep/fd/eza. Metamorphic
  test asserts identical order under `C` and `en_US.UTF-8`. (green, uncommitted —
  shared worktree) 2026-07-23.
- [x] `sessions`: promote alias → `bin/sessions` with `--attached` /
  `--headless`(=`--unattached`) filters over `tmux list-sessions`;
  `bin/test/sessions_test` 13/13. (uncommitted) 2026-07-23.
- [ ] `glob`: loud, **muteable** stderr note stating the active collation + its
  i18n caveat ("code-point order; non-ASCII sorts after ASCII — like rg/fd/eza").
  Pure, tested note fn; mute via truthy `GLOB_MUTE_SORT_NOTE` / `--mute-sort-note`;
  TTY-gated so scripts/pipes/CI stay clean. Show Peter live before fixing the default.
- [ ] `l`: promote alias → `bin/l` (preserve `le`/`l0-3`/`le0-3`/`lsize` family);
  default sort by name (eza already code-point & locale-independent — confirmed);
  add `l --date` → sort by modification date. Same transparent-note treatment.
- [x] `code <partial> [--edit]`: sourced shell function (`bin/src/code.bash`,
  wired into `.bashrc`) that cd's into the first `$CODE`(~/Code) project matching
  `*partial*/` — case-insensitive, dirs-only, code-point-first via `glob -i`;
  `--edit` opens it via `edit` instead. TDD 7/7 (`bin/test/code_test`), shellcheck
  clean, live-verified (`code collat` → collation_mf, `code zed` → zed-…).
  Completed 2026-07-24. (uncommitted)
  - Curiosity poke: a cd-helper MUST be a sourced function; and `${EDIT:-}` (not
    `${EDIT}`) keeps the self-edit hook `set -u`-safe for the test harness.
- [x] dirtree inbox (2026-07-23): plain PageUp/PageDown scroll WezTerm viewport
  instead of jumping shell history. Completed 2026-07-24 11:09 EDT in the
  separate `~/.config` repo at `3f7d0c2`: neither dotfiles `.inputrc` nor
  `.bashrc` mapped PageUp/PageDown (only arrows); WezTerm now intercepts the
  plain keys with `ScrollByPage`, while Shift+Page passes through to the app.

### BIG idea (new, additive) — `collation_mf_do_you_speak_it` (Zig lib + C FFI)
Repo `pmarreck/collation_mf_do_you_speak_it` at `~/Code/`. Delegated to a
background Agent (2026-07-23); this session stays on the dotfiles queue above.
Spun out of the glob/`l` collation dive. **Gap:** glibc locale collation is
non-reproducible (glibc 2.28 reorder silently corrupted PG indexes; musl has NO
`LC_COLLATE` → byte fallback) and ICU is heavy; rg/fd/eza all punt to code-point.
**Opportunity:** a tiny, fast, *opinionated*, cross-libc/cross-OS collation library
that ships its own **versioned** data (reproducible by design), does NFC
normalization + UCA-ish tailoring for a curated language set + **natural-numeric**
sort, exposes a **C FFI** (LuaJIT/Zig/bash-helper consumers), with a **code-point
fallback**. Differentiator vs `icu4x`: small / opinionated / FFI-first / no-Rust-dep
for consumers / natural-sort baked in. End state: `glob` + `l` both consume it →
consistent, correct-ish, reproducible everywhere. Own repo (scaffold-zig-project).
Scope-first hard parts: CLDR tailoring data *source* (do NOT hand-roll tables — the
trap eza's contributor flagged), normalization data, natural+UCA interplay, SIMD
sort-keys, and a deliberate answer to "why not just bind `icu4x`?".

## Recent

- [x] Keep `rg` stdin-filter mode from being mistaken for an implicit search of
  the current directory, which currently makes shell startup from `$HOME`
  produce duplicate whole-home refusal warnings. The guard now mirrors
  ripgrep's distinction: FIFO and regular-file stdin are stream inputs, while
  terminal, `/dev/null`, or closed stdin imply `.`. Completed 2026-07-23 08:26
  EDT; all 39 focused tests, ShellCheck, an exact `$HOME` acceptance check, and
  all 150 repository test files pass.
  - Curiosity poke: retain both sides of the classifier in tests so fixing
    stream filtering can never weaken the implicit-directory safety gate.
- [x] Fix the last remaining `fun_intro_test` failure (image-pick cache regen).
  Root cause: `--regenerate-cache --pick=<image>` runs `inthebeginning` →
  `display_image`, whose live protocol auto-detection cannot succeed in the
  background/no-TTY regenerator (and never could — even an expect PTY can't
  answer a graphics query), so it exited 1 with no bytes and the image_capable
  bucket never diverged from its hardlinked text sibling. Fix: added an opt-in
  `DISPLAY_IMAGE_FORCE_PROTOCOL` env override to `display_image` (bypasses
  detection; `-p` still wins) and had `fun_intro`'s regenerator force the
  protocol for image picks, reusing the login shell's already-probed
  `KITTY_CAPABLE`/`SIXEL_CAPABLE` (default kitty). New `display_image_test`
  (8 assertions) written TDD-first (red→green). `fun_intro_test` now 12/12;
  `fun_intro_cache_test` 7/7. Completed 2026-07-22 21:36 EDT.
  - Curiosity poke: an env assignment produced by *expansion*
    (`${prefix}cmd`) is NOT recognized as an assignment — it becomes the
    command (→ 127). The fallback path must `export` in a subshell; only the
    expect path can embed a literal prefix (re-parsed by `sh -c`).
- [x] Make the `/nix/store` traversal guard multicall: dispatch as ripgrep,
  GNU/BSD find, or fd according to its invoked name, with `~/bin/find` and
  `~/bin/fd` symlinked to the guard and the same sudo-only, loudly discouraged
  escape hatch. Gate only the exact expensive roots, leaving specific home
  directories, Nix derivations, and bounded profile aliases searchable. Direct
  whole-home searches to the existing `fsearch --cli` index. Completed
  2026-07-22 18:04 EDT; all 38 focused tests, ShellCheck, real fd smoke tests,
  and the affected `executables_test` integration suite pass. Full repository
  suite is back to its pre-existing baseline: 148/149 test files pass; only the
  unrelated `fun_intro_test` hardlink/image-cache case remains red.
  - Curiosity poke: find expressions and fd patterns/exclusions may legitimately
    contain `/nix/store`; only traversal-root operands should trigger.
- [x] Guard `rg` against recursive `/nix/store` traversal, with an explicit
  sudo-only emergency path that still emits a severe warning, and ensure agent
  shell tooling cannot bypass it through PATH precedence. Completed 2026-07-22
  17:12 EDT; 12 focused tests and shell-startup coverage pass. The unrelated
  pre-existing `fun_intro_test` image-cache case remains the sole full-suite
  failure (148/149 test files pass).
  - Curiosity poke: patterns can themselves contain `/nix/store`; classify
    search roots without rejecting a harmless literal-pattern search.
- [x] Retarget the Darktide mod sync and loader-patch helpers to the dedicated
  NVMe Steam library, then dry-run and restore the Windows-sourced mods.
  Completed 2026-07-22 00:17 EDT: all Windows mod content was already present;
  preserved the newer Linux load order and restored the stripped bundle patch.
  - Curiosity poke: Steam updates and integrity checks can preserve mod files
    while silently removing the bundle loader patch.
- [x] Make `erect-agent-stack` continue the latest cwd-scoped Claude context;
  explicitly trust the canonical Codex project path; and require visible Codex
  chrome before reporting readiness or delivering a ping. A guarded,
  case-insensitive `do you trust` fallback handles older gates without coupling
  to their full wording. (2026-07-21 19:43 EDT)
  - Curiosity poke: Codex persists CLI trust overrides in `config.toml`; tests
    must use real project roots or clean their temporary entries afterward.
- [ ] Route disposable Cargo and Zig compiler state to `/mnt/devcache` through
  a readiness-gated `.envconfig` policy, with repository-isolated local caches
  and interactive directory-change refresh.
  - Curiosity poke: existing agent processes retain old environments until a
    new command shell is spawned; validate both Codex and Claude empirically.
- [ ] Empirically test Codex bracketed-paste submission with the target tmux
  session unattached, attached and visibly shown, and attached but hidden.
  - Curiosity poke: does the outer terminal's visibility affect the pane PTY at
    all, or is `session_attached` the only potentially observable variable?
- [x] Make `erect-agent-stack --agent codex` bypass first-run project trust,
  recognize Codex readiness, and submit `--ping` via bracketed paste plus a
  plain Enter without timing sleeps. (2026-07-17 10:10 EDT)
- [x] Preserve NixOS privileged-wrapper precedence when rebuilding PATH, with a regression test for `sudo`. (2026-07-10 14:51 EDT)

## Open

### Structured event emission (multi-phase, in design with project-manager)

Phase 1 scope (when implementation starts):
- `capture_json` (bash shim → LuaJIT helper, FFI write(2), printable-binary-encoded string fields, schema `"v":1`)
- minimal `structured.bash` (sourceable lib exposing emit_event / emit_out / emit_err / with_context / route_structured_to_std)
- `probe expect_empty` and `probe expect_rc` (LuaJIT-native, one fork per invocation, in-process emit)
- `with_context` (argv form only, no `--shell` yet)
- chunk-sentinel protocol for events > PIPE_BUF (4 KB), defined upfront
- event sink default: `${STRUCTURED_SINK_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}}/structured/session-$$.ndjson`

Phase 2+:
- `with_context --shell` (parse `|`/`||`/`&&`, each unit `bash -c`'d)
- `probe expect_match` / `probe expect_lt`
- Auto-titling terminal view (subscribes to context_push/pop)
- Other "views" (TUI, replay, test-assertion, aggregator)
- Mid-stream FD peeking for non-cooperative pipeline visibility
- Trace-ID env-var propagation (only if cross-fork correlation becomes needed)

Hard invariant: `structured.bash` must NEVER be transitively pulled into shell startup (`.bashrc` / `.profile` / `.pathconfig`). Opt-in only.

### LuaJIT dependency verification (revisit)

Phase-1 plan is to assume `luajit` on PATH and bail with a clear error if missing (the shebang wouldn't resolve anyway). Longer-term, decide:
- Should there be a `bin/vendor/luajit` symlink for an explicit/discoverable dep contract?
- Should the install script verify all hard deps up front (luajit, jq if we add it, printable-binary, etc.) and either warn or block?
- Should `structured.bash` self-disable (per the no-op + warn fallback) instead of bailing?

Lean toward "install script verifies + structured.bash self-disables" but no rush — defer until first new-machine bootstrap reveals the rough edges.

# dotfiles — TODO / Plans

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
- [ ] dirtree inbox (2026-07-23): plain PageUp/PageDown scroll WezTerm viewport
  instead of jumping shell history — find the readline/shell mapping responsible.

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

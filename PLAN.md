# dotfiles — TODO / Plans

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

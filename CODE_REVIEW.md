---
purpose: Full audit of the ~/dotfiles shell-config as a whole, framed on Peter's two axes plus orthogonal quality.
audience: both
maintained_by: agent
---

# Code Review — ~/dotfiles shell configuration

**Date:** 2026-07-24
**Reviewer:** Claude (deep-code-review, 6 parallel read-only reviewers)
**Scope:** rc/load chain (`.bash_profile`, `.bashrc`, `.profile`, `.envconfig`, `.shellenv`, `.pathconfig`, `.aliases`) + sourced function library (`bin/src/*.bash`, `bin/apply-hooks`) + test infrastructure (`bin/run_test_suite`, `bin/test/*_test`).
**Method:** each finding verified against source (many confirmed by running isolated `env -i bash` reproductions). Buckets = Peter's framing: **B-axis1** (cross-platform parity), **B-axis2** (interactivity gating), **A** (orthogonal).

## Summary
- **CRITICAL 🔥:** 4
- **WARNING ‼️:** ~19
- **ADVISORY ⚠️:** ~18

---

## ★ Cross-cutting headline — `.shellenv` is orphaned (flagged independently by 4 of 6 reviewers)

Nothing in the live source chain sources `.shellenv`, and `BASH_ENV` is never wired — yet its own header (`.shellenv:8-11`) claims `~/.bash_profile`/`~/.bashrc`/`$BASH_ENV` source it, `install_dotfiles:25` symlinks it to `~/.shellenv`, and `bin/test/shell_startup_test` exercises it. So its clean, consolidated implementations (GNU-sed detection, PLATFORM, EDITOR/VISUAL, GREP_QUIET, VOLTA, shell-characteristics, the `__SHELLENV_LOADED` marker, the non-Volta/pnpm shadow warning) **never run**, while slightly-divergent duplicates in `.bash_profile`/`.bashrc`/`.envconfig`/`.profile` are what actually execute.

**This is the "half-finished refactor" you sensed.** It is the single highest-leverage decision in this review and it gates much of the duplication cleanup below.

**Decision (yours):**
- **(a) Finish it** — source `.shellenv` guarded from `.bash_profile` + `.bashrc`, wire `BASH_ENV=~/.shellenv`, then delete the live duplicate blocks (§A-dup #6/#7). Collapses the env surface from 4 files to 1. OR
- **(b) Delete it** — remove `.shellenv`, `install_dotfiles:25`, and `bin/test/shell_startup_test`.
- Leaving it half-wired is the worst state: it reads as authoritative but is dead, so future env edits land there and silently do nothing.

---

## B — Axis 1: cross-platform parity (macOS aarch64 ↔ NixOS Linux)

### WARNING ‼️
- **`.aliases:106` — `log` alias breaks on NixOS.** `alias log='/usr/bin/script -a …'`. NixOS `/usr/bin` holds only `env`; real `script` is on PATH at `/run/current-system/sw/bin/script`. Absolute path bypasses PATH → "No such file or directory" on Linux (works on macOS BSD script). Both GNU+BSD `script` accept `-a`. **Fix:** `alias log='script -a ~/Terminal.log; source ~/.bash_profile'`.
- **`.bashrc:178` — `ARCHFLAGS` garbage on macOS (the OS that uses it).** `ARCHFLAGS="-arch $(uname -a | rev | cut -d ' ' -f 2 | rev)"` grabs the 2nd-to-last `uname -a` token. On macOS the arch is the *last* token → yields `-arch RELEASE_ARM64_T6031`; exported and read by Ruby `mkmf`/native builds → can break native-ext compiles on macOS. **Fix:** gate on `[ "$PLATFORM" = mac ]` and use `uname -m`/`arch`; don't set on Linux.

### ADVISORY ⚠️
- **`.envconfig:61` — `--enable-darwin-64bit` in `KERL_CONFIGURE_OPTIONS` unconditionally.** On Linux kerl, autoconf warns+ignores (noise). **Fix:** append only under `[ "$PLATFORM" = mac ]`.
- **`.bashrc:237-240` — inverted GNU-awk warning** (also §A-correctness #8). Fires when `is_gnu_awk` is *true*; never correct. **Fix:** `[ "$PLATFORM" = mac ] && ! $is_gnu_awk && echo …`.

### ✅ Verified good (do not re-flag)
- **NixOS sudo-wrapper precedence is INTACT** — live PATH has `/run/wrappers/bin` (pos 94) ahead of `/run/current-system/sw/bin` (pos 99); `.pathconfig` force-prepends the unwrapped dir only on `darwin*` (142-144). The 2026-07-10 regression stays fixed.
- GNU-tool wrappers (`bin/sed`→gsed, date/stat/tac/shuf/timeout) + `$HOME/bin` ahead of BSD `/usr/bin` cover macOS correctly. Platform gates are correctly *split* where they must differ (pman/open/clip/tophog/killdns/distro). Load-order parity holds across mac (all-login) vs Linux (non-login GUI).

---

## B — Axis 2: interactivity gating

**Net:** no unconditionally-loaded interactive machinery — no ungated `tput`/`bind`/`starship init`/`read`/`gum`/OSC/PROMPT_COMMAND in non-interactive contexts. Define-files only define + self-guard. The real defects are **fail-open guards**.

### WARNING ‼️
- **`.profile:15` — fail-open guard emits to STDOUT in login `sh`.** `$INTERACTIVE_SHELL && $LOGIN_SHELL && echo "$DISTRO_PRETTY"` — bare (undefaulted) vars. When `INTERACTIVE_SHELL` is unset, `$INTERACTIVE_SHELL &&` is an empty command → exit 0 → falls through. `.profile` is POSIX and sourced by non-bash login shells (`sh -lc`, cron w/ login sh, display-manager); nothing sets the var there → `echo` fires → **corrupts captured command output**. **Fix:** `${INTERACTIVE_SHELL:-false} && ${LOGIN_SHELL:-false} && echo …` (the form already used at `.pathconfig:14`, `.profile:40/169`, `session.bash:20`). *(Verified empirically with `env -i bash`.)*
- **`.envconfig:3` — same fail-open → STDERR `command not found` in agent shells.** `… || $INTERACTIVE_SHELL && $LOGIN_SHELL && append_dotfile_progress "env"`. `.envconfig` is loaded by agent/non-interactive shells (`apply-hooks:163`, `rehash:26`, `BASH_ENV`) and never sources `append_dotfile_progress` → standalone sourcing throws `command not found` per agent shell. **Fix:** `… || { ${INTERACTIVE_SHELL:-false} && ${LOGIN_SHELL:-false} && command -v append_dotfile_progress >/dev/null && append_dotfile_progress "env"; }`. (`.profile:12` has the same bare pattern — harmless today, fix in the same pass.)

### ADVISORY ⚠️
- **`.envconfig:202` — `export GPG_TTY=\`tty\`` runs in agent shells** → `GPG_TTY="not a tty"`. Benign (captured) but bogus. **Fix:** `[ -t 0 ] && export GPG_TTY="$(tty)"`.
- **`.profile:149/:161` — terminal-capability probes** (`check_sixel_support`/`check_kitty_support`) run unconditionally on every shell reaching `.profile`. No corruption (no DA1/OSC queries; all captured), just an `infocmp`+`ps` fork/shell. Optionally gate on `${INTERACTIVE_SHELL:-false}`.
- **(inverse) `.profile:169` — `fun_intro` requires LOGIN *and* INTERACTIVE**, so non-login interactive shells (plain `bash -i`, editor subshells, non-login tmux panes) never see it. Fine if login-only is intended; contrast `.bashrc` keybindings/aliases + `session.bash` quickref which gate on INTERACTIVE *without* LOGIN.

---

## A — Correctness & Security

### WARNING ‼️
- **🔒 `.pathconfig:106-120` — PATH shadowing (security).** `for _dir in "$CODE"/*/result/bin "$CODE"/*/zig-out/bin "$CODE"/*/bin; do PATH_ADDITIONS+=("$_dir")` — these are **prepended to the FRONT** of PATH. Any repo cloned under `~/Code` shipping a `bin/` silently overrides system binaries in every future shell — a hostile `bin/sudo`/`bin/git`/`bin/ls`/`bin/grep` runs ahead of the real one. Real local supply-chain footgun given the clone-many-repos + agent-fleet workflow. (Glob handling itself is correct — `set +f`/`nullglob`.) **Fix:** APPEND instead of front-prepend, or gate behind a trusted-project allowlist.
- **`.bashrc:71` — LLM/parent-proc detection silently NEVER matches** (also flagged by axis-1). `ps -p $PPID -o comm= | rg -q --fixed-strings "claude\|llm\|assistant"` — `GREP_QUIET` defaults to `rg -q --fixed-strings`, so the BRE-alternation pattern is matched *literally* (backslash-pipes included) → never matches `claude`. The parent-process `SKIP_COMPLEX_SHELL_SETUP` path is dead whenever `rg` is installed (the normal case). **Fix:** `rg -q -e claude -e llm -e assistant` (no `--fixed-strings`) or `grep -qE 'claude|llm|assistant'`.
- **`${EDIT}` unbound under `set -u` — 38 sites / 17 files.** Every editable function opens `[ -n "${EDIT}" ] && …`; under `set -u` with `EDIT` unset this aborts the caller. Any `set -u` script that calls `needs`/`prepend_path`/`show`/`functions`/… dies. Sites incl. `.bashrc:260`, `bin/needs:4`, `prepend_path.bash:3/43/103`, + compsavings/utility_functions/bashorg_quote/weather/calc/shadows/edit/show/git_commit_ai/fsattr/job_control/source_relative/functions/clock/nvidia/warhammer_quote. **Fix:** `${EDIT:-}` everywhere. *(Same class as the `code.bash` bug already fixed this session.)*
- **`.aliases:195` — `timeout` alias shadows the real binary unconditionally.** `needs timeout 2>/dev/null || needs uutils-timeout … && alias timeout='uutils-timeout'` groups as `{ … } && alias …`, so even when real `timeout` exists the alias runs; if `uutils-timeout` is absent, `timeout` → missing command. **Fix:** `needs timeout 2>/dev/null || { needs uutils-timeout "…" && alias timeout='uutils-timeout'; }`.
- **`.envconfig:298-299` — readonly re-declare spams stderr on reload.** `declare -irx BASH_INT_MAX=…` re-run on `source ~/.bashrc` → `bash: declare: BASH_INT_MAX: readonly variable`. **Fix:** `[[ -v BASH_INT_MAX ]] || declare -irx …` (and MIN).

### ADVISORY ⚠️
- **`claude.bash:4` / `codex.bash:5` — empty resolved path runs user args as a command.** `local claude_path=$(which claude); $claude_path "$@"` — if not on PATH, runs `"$@"` bare (the no-arg path would execute `--resume --dangerously-skip-permissions` as a command). **Fix:** `[ -n "$claude_path" ] || { echo "claude not found" >&2; return 127; }`.
- **`.pathconfig:19-23` — documented recovery is impossible.** Comment says `unset ORIG_PATH; . ~/.pathconfig`, but line 23 `readonly ORIG_PATH` → unset fails; only works in a fresh shell. **Fix:** correct the doc or drop `readonly`.
- **`capture.bash:107/150`** — restore turns an originally-unset var into an exported empty `""`. Minor.
- Debug-line precedence (`… && echo "Entering" || $INTERACTIVE_SHELL && …`, multiple files) — in DEBUG mode the trailing `append_dotfile_progress` still runs. Cosmetic.

### ✅ Verified good
No `set -e`/`set -u` in the sourced/interactive chain; `exit`s in `bin/src` are awk/subshell-scoped; `.pathconfig` rebuild is idempotent (self-tested); no world-writable/`.`/`/tmp` PATH entries; `~/.secrets` sourcing is standard.

---

## A — Duplication & Dead Code

### CRITICAL 🔥
- **`.bash_profile:54-61` — dead SED-detection block.** Detects+exports `SED`, then line 73 `unset SED` and 74-84 re-detect from scratch → the first block is 100% dead. **Fix:** delete `.bash_profile:53-66`; keep the 68-84 detector.

### WARNING ‼️
- **13 stale `.bak` files in `bin/src/`** (date_difference_days, div, dragon, ds_bore, flip_a_coin, mandelbrot, notify, otp_version, repeat_command, roll_a_die, rpn, Time.now.to_f, utility_functions) — no live same-name sibling; `utility_functions.bash.bak` is a 525-line stale copy of the live 297-line file. **Fix:** delete all (git history is the backup). *(Zero risk.)*
- **`truthy.sh` sourced from 4 files with 3 guard styles** (.bashrc:39 / .envconfig:7 / .shellenv:36-dead — all unconditional; .profile:10 guarded) → re-sourced ≥2×/shell. **`append_dotfile_progress.sh`** similarly 3 idioms (.bash_profile:27 / .pathconfig:13 / .profile:11). **Fix:** standardize on `func_defined X ||` at every site; drop `.envconfig:7`.
- **`capture.bash` sourced twice in `.profile`** (:138 and :144). **Fix:** delete one.
- **VOLTA/PNPM env + PATH prepend duplicated across 5 files** (VOLTA_HOME in .bash_profile:120/.profile:201/.shellenv:94/.envconfig:124/.bashrc:369) and the manual `export PATH="$VOLTA_HOME/bin:$PATH"` at .bash_profile:122/.profile:202/.bashrc:370 is **dead weight** (`.pathconfig:82` already adds `~/.volta/bin` idempotently) *and* reorders PATH after `.pathconfig` built it. **Fix:** keep env in one always-live file; delete the manual prepends.
- **Platform/EDITOR/GREP_QUIET/interactive-detection blocks duplicated** between `.bashrc` (live) and `.shellenv` (dead), plus `LANG` set in 3 files — the exact blocks the `.shellenv` refactor was meant to unify (see headline).

### ADVISORY ⚠️
- **`bin/src/utility_functions.bash` — grab-bag catch-all AND never sourced in the live chain** (only a comment ref at `apply-hooks:99`); several functions shadowed by `bin/` executables (`needs`, `__wezterm_osc7`). Its `:158` also has a merge-artifact syntax error `… :fi` (see testing §). **Fix:** split still-used functions into named files or delete the dead remainder.
- **Large commented-out dead blocks** — `.profile:29-113` (~85 lines of git helpers incl. a VS Code `code()`), `.envconfig` (Homebrew gcc / Ruby GC / IRC), `.bashrc` (asdf/ble.sh/LM Studio/Warp). `.profile` is ~70% dead comments. **Fix:** delete (git history).
- **`.aliases` — `lc='wc -l'` (:203, comment mislabels it "letter count")** duplicates `count-lines='wc -l'` (:220); heavy commented-alias cruft. **Fix:** drop one, fix comment, prune.
- **rc-chain sprawl (7 files)** with cross-cutting concerns mixed; `.bashrc` sources `.envconfig`+`.profile`+`.aliases` from its middle/bottom (:278/:281/:328) → non-obvious order. Realizing the `.shellenv` consolidation is the highest-leverage fix.

---

## A — Testing / "one command" convergence

**Verdict:** the convergent runner already exists and is well-built: **`bin/run_test_suite`** (deterministic nullglob discovery of `bin/test/*_test`, isolated subprocess per test, exit = sum of failures capped 255, restores glob state, self-tested by `run_test_suite_test`). `bin/test_dotfiles` is a legit thin shim. Cleanup = remove the older strata + add ~4 tests.

### CRITICAL 🔥
- **`bin/dotfiles_test` — stale divergent duplicate runner.** Diverges on load-bearing axes: `:44` **sources** tests instead of exec'ing them (different isolation), `:58/:128` **uncapped** exit sum (>255 wraps mod 256 → misreports), `:105` **re-runs every failed test** (doubles cost, non-idempotent), merges stderr into stdout, no self-test. **Fix:** delete; callers use `run_test_suite`/`test_dotfiles`.

### WARNING ‼️
- **Dead `RUN_DOTFILE_TESTS` inline test blocks** in `utility_functions.bash:154-233` (calls an **undefined** `run_test_suite name : fn :` harness; `:158` has a `:fi` syntax error) + prepend_path/calc/fsattr/ff_fast_find/job_control/print_x_times. Plus `run_tests_on_change.sh` + `.bash_profile:104-106` (double-gated, never fires). **Fix:** delete the inline blocks (standalone `bin/test/*_test` already cover them); retire the change-watcher.
- **`bin/test/shell_startup_time_test` — wall-clock, tmux-spawning benchmark inside the pass/fail suite** → flaky-by-design (violates your "sleeps/timing = smell"). **Fix:** move to a benchmark lane (rename off `*_test` or env-gate so `run_test_suite` skips it). *(7 other suite tests also use real `sleep`: audio_convert, clip, fun_intro_cache, getfile, nethogs, terminal_config, timed.)*
- **Missing `bin/test/source_relative_test`** — the core sourcing primitives (`source_relative.bash`/`source_relative_once.bash`) the whole model rests on have zero coverage. **Fix:** add (once-idempotency, relative resolution, missing-file exit).

### ADVISORY ⚠️
- **Interactivity-gating is untested** — `shell_startup_test` explicitly excludes decoration; nothing asserts "prompt/aliases/fun_intro load iff interactive" / "non-interactive stays quiet+cheap". **Fix:** add that test (it would also lock in the axis-2 fixes above).
- Missing function-level `prepend_path_test` / `expand_glob_test` (only tested transitively).
- `--test` contract inconsistent (`calc:90` doesn't mute stdout, unlike `run_test_suite:135`). Low blast radius (runner executes `bin/test/*_test` directly).
- ✅ Good: PATH + **sudo-precedence IS tested** (`pathconfig_bash_prepend_test`); `edit`/`code`/`glob`/`resolve`/`capture`/`session` have tests.

---

## A — Hook lifecycle (starship / mcfly / wezterm) — *your "stepping on each other" pain*

All hook registration is centralized in `bin/apply-hooks` (sourced from `.bashrc:305/312`, gated interactive & non-agent at `.bashrc:297`). Strategy = "wipe `PROMPT_COMMAND`, re-run every tool's init, harvest". That breaks tools with a once-guard.

### CRITICAL 🔥
- **`bin/apply-hooks:41` + `:128-131` — McFly is permanently dropped on any `.bashrc` re-source.** apply-hooks wipes `PROMPT_COMMAND` then re-runs each init; but `mcfly init bash` sets `__MCFLY_LOADED=loaded` and its init becomes a no-op forever in-process. On the 2nd+ source (manual `source ~/.bashrc`, nested `.bash_profile`→`.bashrc`, any re-source), mcfly's prompt command is wiped and never re-harvested → **McFly silently stops recording history**. *Proven empirically* (mcfly present before re-source, gone from both `precmd_functions` and `PROMPT_COMMAND` after). **Fix:** `unset __MCFLY_LOADED` immediately before `eval "$(mcfly init bash)"` at `:129`, or post-init `array_contains_element precmd_functions mcfly_prompt_command || precmd_functions+=(mcfly_prompt_command)`.

### WARNING ‼️
- **`bin/apply-hooks:154` — Starship PS0 timing magic accumulates unboundedly on re-source.** The clean-slate (`:40-48`) resets `PROMPT_COMMAND`/`precmd_functions`/`preexec_functions` **but not `PS0`**, so each re-source prepends another `starship time` invocation to `PS0` → an extra subprocess spawned **per command run** (proven 2→3). Growing keystroke latency. **Fix:** add `PS0=''` to the clean-slate at `:44`, or guard: `[[ "$PS0" == *starship_preexec_ps0* ]] || PS0=…`.
- **`bin/apply-hooks:158-160` — double OSC 7 emitter clobbers cwd with `$HOME`.** `__wezterm_osc7` (`:136`, `$PWD`, WezTerm-gated) and `__wezterm_osc7_home` (`:158`, `$HOME`, **unconditional**, runs *last*) both land in `precmd_functions` → every prompt sets the terminal's working dir to `$HOME` → **new tabs/splits open in `$HOME` instead of cwd**; also fires a spurious `wezterm set-working-directory $HOME` on non-WezTerm terminals. **Fix:** drop `__wezterm_osc7_home` (remove `:158-160`); keep only the `$PWD` emitter.

### ADVISORY ⚠️
- **`bin/apply-hooks:214/:226` — bash-preexec DEBUG trap is killed → `preexec_functions` globally dead.** Intentional (hang avoidance, comments `:218-225`), but starship's `starship_preexec_all` in `preexec_functions` is dead weight and timing survives only via the PS0 hack — two competing mechanisms, one silently disabled. **Fix:** make the "preexec disabled by design; timing is PS0-only" contract an explicit comment; consider removing the redundant starship preexec entry.
- `move_PROMPT_COMMAND_to_precmd_functions` (`utility_functions.bash:73-94`) is dead code (zero callers).

### ✅ Verified NOT bugs
No precmd/preexec double-registration on re-source (clean-slate + guarded harvest are clean — mcfly is the sole casualty); `$?`/PIPESTATUS safe across precmd ordering (bash-preexec restores `$?` and exposes `BP_PIPESTATUS`); up/down-arrow history bindings don't collide with mcfly (mcfly binds only `C-r`).

---

## Suggested order of operations

**Zero-risk cleanup first (no behavior change):**
1. Delete the 13 `.bak` files; delete `.bash_profile:53-66` dead SED block; delete the duplicate `capture.bash` source (`.profile:144`).
2. Delete `bin/dotfiles_test`; delete the dead `RUN_DOTFILE_TESTS` inline blocks + `run_tests_on_change.sh` wiring; fix the `:fi` syntax error by deletion.
3. Prune the large commented-dead blocks and the duplicate `lc`/`count-lines` alias.

**High-value correctness/security (TDD where testable):**
4. `${EDIT}` → `${EDIT:-}` across the 38 sites (mechanical; add the interactivity-gating test to lock behavior).
5. PATH-shadowing: append `~/Code/*/bin` instead of front-prepend (or allowlist).
6. Fix the two fail-open guards (`.profile:15`, `.envconfig:3`); `timeout` alias grouping; readonly re-declare guard; `.bashrc:71` LLM-detect regex.
7. Hook fixes: `unset __MCFLY_LOADED` before mcfly init; reset `PS0` in the clean-slate; drop `__wezterm_osc7_home`.

**Cross-platform:**
8. `.aliases:106` `log` (drop absolute path); `.bashrc:178` `ARCHFLAGS` (gate+`uname -m`); inverted awk warning; kerl darwin flag.

**The big decision (do before the duplication cleanup it gates):**
9. **`.shellenv`** — finish-and-wire (then delete duplicates) OR delete. §headline.

**New tests to add:** `source_relative_test`, interactivity-gating test, `prepend_path_test`/`expand_glob_test`; move `shell_startup_time_test` out of the pass/fail lane.

---

## 2026-07-28 milestone review — `fleet-status`

Three independent read-only passes reviewed correctness/test quality,
macOS/Linux portability/security/cache behavior, and code organization after
the all-tier implementation.

### Resolved before release

- Git status, orphan reachability, branch enumeration, remote enumeration, and
  stash failures now become named `unknown` risks and `partial` tier health;
  none can masquerade as clean/safe/zero.
- Repository cache identity now fingerprints origin, HEAD/branch, every
  supported lockfile, and the Mechatron target manifest. Provider answers are
  separately cached by exact command, removing repeated dependency queries.
- Every external provider call has a configurable 30-second process deadline.
- Provider and cache JSON shapes are validated and collectors are isolated, so
  malformed data degrades only the affected field.
- Real-fleet parser omissions now have fixtures: abbreviated and quoted Zig
  pins, non-comparable Zig archives, GitHub `type=git` flake inputs, Cargo
  dependency tables, npm v1 locks, and npm/pnpm workspaces.
- Direct-child discovery is bounded at depth two, avoiding recursive vendor
  traversal; Apple and Linux `find` both support the used primitives.
- Snapshot/report publication is serialized with an atomic state lock.
  Repository-controlled terminal/Markdown control characters are escaped.
- Exact scheduler fields, executable naming, CLI integer/about contracts, and
  both local/hermetic full-suite gates are enforced.

### Design choice resolved: bold hexagonal split

Peter selected the bold option. `lib/fleet_status.lua` is now a thin, stable
composition root wiring pure renderers and lock parsers to constructor-injected
local Git, state, provider, runtime, and network-orchestration modules. Network
orchestration has no direct host I/O; those effects cross the runtime port.

An architecture contract enforces the exact dependency graph, facade size,
pure-domain boundaries, host-I/O boundary, complete public API, and actual
adapter substitution with fake ports. Existing collector, renderer, state,
nightly, and network suites continue to enforce behavioral and byte-level
compatibility. The completed split passed all 168 raw-host tests and all 119
hermetic Nix tests.

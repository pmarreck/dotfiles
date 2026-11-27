# LuaJIT shell startup rewrite

Goal: reach a usable interactive prompt quickly on every supported Bash entry
point without changing what the startup files establish. Shared computation
moves into one LuaJIT process per startup; current-shell effects (aliases,
functions, prompt hooks, options, traps) stay in thin Bash.

## Measurement method

`bin/shell-startup-bench` spawns Bash on a real PTY under `expect`, types a
command immediately, and stops the clock when the command's output appears.
Typed input waits in the PTY until the shell reads it, so a sample ends at the
first prompt that accepts input. The default environment is clean (HOME, USER,
LOGNAME, TERM, LANG, PATH=ORIG_PATH), like a new terminal tab, and the intro
is skipped unless `--decorated` is given.

Wall-clock numbers drift with machine load (the same tree measured 541 ms and
then 670 ms an hour apart). Compare trees only in interleaved A/B rounds under
identical fixture homes: link every real `$HOME` entry into two directories,
point each one's `dotfiles` at a different tree, and alternate
`HOME=<fixture> shell-startup-bench` runs. Fixture homes read slower than the
real home because every path passes through symlinks; only the difference
between sides is meaningful.

`util-linux script` is unsuitable as a PTY driver here: piping input through it
quantizes exits to about 250 ms, so a bare `bash --norc` appeared to take
273 ms.

## Baseline (Linux, 2026-11-27, commit 9c214ce)

Clean environment, intro skipped, medians of 12 samples:

| Route | Time to first prompt |
|---|---|
| bare `bash --noprofile --norc -i` | 13.7 ms |
| non-login interactive (terminal tabs) | 835 ms |
| login interactive | 856 ms |

A clean non-login startup performed 143 successful `execve` calls and about
3,850 failed ones. The failures are PATH probes: `/usr/bin/env bash` tries each
of the 167 PATH entries, and `/run/current-system/sw/bin`, which holds Bash and
most tools, is last.

Attribution from an xtrace run (wall time per line, inflated by tracing):

| Cost | Source |
|---|---|
| ~192 ms | 16 executed `needs` calls for 10 distinct tools, about 9 ms each |
| ~66 ms + ~34 ms | `.pathconfig` built twice on non-login startup |
| ~54 ms | `distro`, `distro_pretty`, `distro_version` scripts |
| ~40 ms | `check_sixel_support`, `check_kitty_support` |
| ~40 ms | GNU tool detection running six `--version` commands |
| ~34 ms | executed `array_contains_element`, which also could not see the caller's arrays |
| ~24 ms | nine `uname` calls (platform environment is configured twice) |
| ~21 ms | devcache's `git rev-parse` through two wrapper layers |
| ~15 ms | `starship`, `direnv`, `mcfly` init commands |
| ~14 ms | `is_nix_darwin` |

Unit costs without tracing: an executed `needs` costs 9.3 ms, the sourced
function 0.4 ms, a `luajit` start 1.8 ms, and `uname` 2.5 ms. LuaJIT pays off
where one run replaces several processes or a large in-Bash loop.

## Increments

A. Done: build PATH once per startup and define `needs` and
`array_contains_element` in the current shell. Interleaved A/B against 9c214ce:
non-login 1,013 → 770 ms (−24%), login 1,067 → 885 ms (−17%), in fixture homes.
`bin/test/shell_startup_exec_budget_test` keeps the forks at zero.

B. Done: PATH construction in LuaJIT (owner's design: Lua prints
definitions, Bash evals them). `lib/shell_startup/path_plan.lua` holds the
rules as a pure function with injected filesystem and collation;
`path_env.lua` prints `NAME='value'` lines through `shell_assign.lua` (names
must match `^[A-Za-z_][A-Za-z0-9_]*$`; `'` becomes `'\''`, lossless for every
byte except NUL). `.pathconfig` keeps current-shell work (ORIG_PATH capture,
helper functions, platform facts, `nix-daemon.sh`) and its one `export PATH`.
It finds `luajit` through Nix profile candidates before PATH exists
(`SHELL_STARTUP_LUAJIT` pins one), and on any failure prints a message, leaves
PATH unchanged, and evaluates nothing. Evidence:
`pathconfig_differential_test` matches the frozen pre-port Bash `.pathconfig`
across 48 seeded cases (both mutants tried were caught; the Nix check supplies
an `en_US.UTF-8` archive so collation is really exercised),
`shell_assign_test` round-trips 591 hazardous values, and
`pathconfig_engine_failure_test` covers the failure paths. Sourcing
`.pathconfig` fell from 75 ms to 21 ms; interleaved A/B against increment A:
non-login 755 → 705 ms, login 877 → 832 ms.

Port details worth keeping: Bash sorts glob matches by full path under
strcoll, not by directory name (in `en_US`, `a b/bin` sorts before `a/bin`),
so the engine sorts full candidate paths. Intentional difference: the old
loops glob-expanded PATH entries containing `*`, `?`, or `[` whenever noglob
was off; the engine never does.

C. Done, re-scoped: platform and distribution forks.
- On Linux the engine run also prints DISTRO, DISTRO_PRETTY, and
  DISTRO_VERSION, parsed by `os_release.lua` exactly as the `distro*`
  commands' awk programs read `/etc/os-release` ($2 ends at the next `=`;
  every match prints; command substitution drops NULs and trailing newlines).
  `os_release_facts_test` compares 222 real, adversarial, and fuzzed files
  against the commands themselves; mutants that strip every quote or skip the
  second `=` are caught. A missing file yields empty facts silently (the
  commands' "Unknown" stderr notice is not reproduced; the Nix sandbox has no
  os-release).
- `configure_platform_env` reads `uname` once per shell process (a
  non-exported memo keyed to `$$`), so `.envconfig`'s second call stops
  forking and children still read their own kernel. `uname` itself stays in
  Bash: a dozen tests inject the platform by shadowing it there.
- `.aliases` answers "nix-darwin?" from the classified `OS` instead of forking
  `is_nix_darwin` twice, and `.bash_profile` runs `check-system-mutations`
  only on macOS.
- The exec-budget test now holds `is_nix_darwin` and `distro` at zero
  everywhere, and on Linux the other distro helpers and
  `check-system-mutations` at zero and `uname` at one triple. Run against the
  previous tree it fails 11 of 18 checks.
- Interleaved A/B against increment B: non-login 772 → 656 ms, login
  865 → 758 ms, under load average 12–19, which inflates fork costs; the
  isolated estimate was about 70 ms.
- Still open: macOS distribution facts (`sw_vers`, `distro_version`,
  `mac_os_version_number_to_name`) need a Mac to verify.

D. Tool capability facts: GNU tool detection cached by resolved binary path
(Nix store paths are immutable), terminal image capability without
subprocesses, and the remaining `rg`-based string checks done in-process.

E. Hook initialization: cache `starship init`, `direnv hook`, and `mcfly init`
output by resolved binary path, and find the devcache project root without the
`git` wrapper chain.

F. Terminal intro: one LuaJIT process for picks, a pre-rendered Kitty stream
for the fixed image so startup needs no ImageMagick, and explicit protocol
selection and cache-compatibility tests. Verify Kitty bytes and text fallback
separately from prompt readiness.

## Open questions

- `.shellenv` is still unsourced and `BASH_ENV` is unwired (see
  `CODE_REVIEW.md`). The Lua engine could become what `.shellenv` runs; decide
  before wiring non-interactive startup.
- One clean TTY-less interactive startup took 6.3 s once and then about 0.5 s on six
  repeats (2026-11-27). The cold cost was not attributed; watch for recurrence.
- `set +h` disables command hashing, so every command typed at the prompt walks
  the 167-entry PATH. Not a startup cost, but worth revisiting with PATH order.

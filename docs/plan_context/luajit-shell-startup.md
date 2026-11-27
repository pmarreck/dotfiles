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

B. PATH construction in LuaJIT. Lua computes PATH and prints assignments;
Bash applies them with `eval "$(luajit …)"` (owner's design). Lua emits only
`export NAME='value'` lines: names must match `^[A-Za-z_][A-Za-z0-9_]*$` and
values use single-quote escaping (`'` becomes `'\''`), which is lossless for
every byte except NUL. A round-trip property test proves eval reproduces values
containing spaces, globs, `$`, backticks, quotes, and newlines. The adapter
must find `luajit` by explicit candidates before PATH exists (an SSH base PATH
on macOS lacks Nix), keep foreign-entry preservation and PF precedence, and
fail loudly rather than leave a silently wrong PATH. Existing `pathconfig_*`
tests remain the contract.

C. Platform and distribution facts in the same Lua run: `uname` through FFI,
`/etc/os-release` parsed directly, macOS version from SystemVersion.plist, and
`is_nix_darwin`, removing about 15 processes.

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

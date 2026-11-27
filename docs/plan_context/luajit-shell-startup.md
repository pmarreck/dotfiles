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

Bootstrap on a machine without LuaJIT (owner request): `.pathconfig`
resolves the interpreter through `bin/src/shell_startup_luajit.bash`. Order:
`SHELL_STARTUP_LUAJIT` (a broken pin fails and is never replaced), the Nix
profile locations, the GC-rooted link `$XDG_STATE_HOME/dotfiles/luajit`, then
PATH (searched in-process). Only when all miss does it warn and run
`nix --extra-experimental-features 'nix-command flakes' build --out-link
<that link> nixpkgs#luajit`, so later shells reuse it without Nix. Startup
never runs Nix while LuaJIT is reachable. Evidence: `shell_startup_luajit_test`
(injected candidates, recording Nix stubs) and a manual end-to-end run on
2026-11-27 with `/run/current-system/sw/bin` hidden in a user mount
namespace: the first shell warned, fetched through the daemon, and rebuilt
PATH; the second reused the link silently.

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

Prompt-time devcache (done): `configure_devcache_env` runs before every
prompt. It used to start `git rev-parse --show-toplevel` through the dotfiles
`git` wrapper and the repository-budget runner (about 8 processes and 28 ms per
prompt, even in a non-repository) plus `sha256sum`. `devcache_git_toplevel` now
walks the physical path up to the nearest `.git` directory or file, treats
`.git` internals as outside a work tree, and asks Git only when `GIT_DIR`,
`GIT_WORK_TREE`, or `GIT_CEILING_DIRECTORIES` is set; the digest is memoized
per root. `devcache_git_toplevel_test` compares the walk with Git across 17
directories (repositories, subdirectories, nested repositories, worktrees,
bare repositories, `.git` internals, symlinks) and proves a prompt-time call
starts no Git. Per prompt: 28 ms → 1.8 ms. Lesson: a test's recording `git`
stub must exec the underlying Git, not the dotfiles wrapper, or the wrapper
selects the stub as its "real" Git and the two exec each other forever.

Measurement note: shells started inside a Git repository pay about 150 ms more
for prompt Git work (2026-11-27: 547 ms in this repository against 397 ms in
`$HOME`). `shell-startup-bench` now starts shells in `$HOME` by default;
earlier A/B numbers in this document were all taken inside this repository,
so they remain comparable with each other.

F. Terminal intro (2026-11-27): `bin/fun_intro` and every pick except
`fortune` (native) and `mandelbash` (Bash, by owner decision) now run in one
LuaJIT process over `lib/fun_intro/`. The image ships pre-rendered
(`bin/data/inthebeginning.png` for Kitty, `.six` for Sixel, regenerated by
`bin/src/render-fun-intro-image`), so startup never needs ImageMagick.
`mandelbash` output is deterministic and is memoized under a hash of the
script.

The replay cache and its background regenerator are gone. The cache made the
foreground cheap (a `cat`), but every interactive shell double-forked a Bash
regenerator that ran the next pick inside `expect` with a 5-second deadline.
Under suite load on WSL the ImageMagick render missed that deadline (exit
124), failing `fun_intro_test` there. Over months the regenerator also left
about 170 orphaned `cached.*.new.PID` files in
`~/.cache/dotfiles/fun_intro/`; that directory is now unused and can be
deleted. Live picks, medians of 7 runs at load 11 (2026-11-27): warhammer 4.9 ms,
mandelbash (memoized) 4.7 ms, dragon 5.4 ms, samson 5.3 ms, taoup 6.3 ms,
image 7.5 ms, chuck 7.9 ms, bashorg 15.6 ms, fortune 35 ms (the native
program alone takes 23 to 28 ms). The Bash picks took 35 to 88 ms each, plus
330 ms for an unmemoized `mandelbash`.

Verification findings:
- GNU fold 9.12 in a UTF-8 locale measures display width (wide characters 2,
  combining marks 0) and breaks at any Unicode blank, not just space and tab.
  It is also state-dependent in two places: a backspace after a tab subtracts
  the width of the last printable character (none at the start of input),
  and invalid bytes count one column when first read but none when
  re-measured after a break. `wrap.lua` matches fold on valid UTF-8 without
  backspaces, which is all the joke data contains (asserted by the test).
- Plain `infocmp -1`, which the old Sixel probe ran, hides user-defined
  capabilities, so the terminfo reader searches only the names and standard
  strings. No entry in ncurses 6.6 mentions sixel, so the test also compiles
  synthetic entries with `tic`.
- Image capability moved into the startup engine the same day
  (`lib/shell_startup/graphics_env.lua`): `.profile` only exports what the
  engine computed, and `.bashrc` reads the engine's
  `SHELL_STARTUP_PARENT_COMMAND` for its LLM-assistant check instead of
  running `ps`. That removes check_sixel_support, check_kitty_support,
  infocmp, and ps from every interactive startup (exec-budget test: 0 each;
  1 each with the previous files). Interleaved A/B, 14 samples, load 4 to 10:
  non-login 366.8 → 319.6 ms, login 467.0 → 428.7 ms. SIXEL_ENV now holds
  the probe's verdict only; it used to include infocmp's own error text when
  TERM had no terminfo entry.

GNU tool probes (2026-11-27). `bin/src/export_gnu_tool.bash` ran
`CANDIDATE --version | head -1` for six tools on every startup (31 ms in
isolation), `.bash_profile` repeated the sed search for login shells, and
`.bashrc` piped `awk --version` through the `~/bin/rg` wrapper, a
`#!/usr/bin/env bash` script whose `env` failed 123 PATH lookups before
finding bash. `lib/shell_startup/gnu_tools.lua` now makes both choices with
`--version` answers cached in `~/.cache/dotfiles/gnu-tool-versions`, keyed by
resolved path, invoked name (coreutils is one multicall binary), size, and
mtime; a warm startup probes nothing. Login shells still choose the
`~/bin/sed` wrapper and non-login shells the real sed, as before; that
pre-existing difference is preserved, not endorsed. Startup execve calls:
152 → 12. Interleaved A/B, 14 samples, load 5 to 9: non-login 324 → 259 ms,
login 400 → 312 ms.

Prompt hook init (2026-11-27). apply-hooks ran `direnv hook bash`, `mcfly
init bash`, and `starship init bash` (whose stub runs starship again with
`--print-full-init`) on every interactive startup, about 21 ms under load.
Each output depends only on the binary and the path it was found at; starship
embeds the path it finds by PATH search when run by name, so the engine runs
the tools by name with the new PATH. `lib/shell_startup/hook_init.lua` caches
each script in an immutable file named by a hash of invoked path, resolved
path, size, mtime, and arguments, and prunes a tool's older files when a new
one lands. `bin/src/hook_init_cache.bash` lets apply-hooks use a script only
when the shell would run that very binary: the engine's PATH is unchanged
(otherwise it searches PATH itself; the dotfiles turn hashing off, so `hash`
cannot answer) and no function or alias shadows the name. The text is
evaluated in apply-hooks' own scope, as the tool output was. A first attempt
searched the 165-entry startup PATH in Bash for every tool and cost 10 ms,
half the saving; trusting the engine while PATH is unchanged brought the
shell side to 0.9 ms, plus 1.2 ms in the engine. ghostty_live_shell_test
compares functions and prompt variables after cached and uncached startups
and the cached scripts with live tool output on each host.

G. Headless Ghostty runner (requested and built 2026-11-27). `lib/ghostty_vt`
binds libghostty-vt through the LuaJIT FFI (`forkpty`, `poll`, Ghostty's VT
engine, its formatter and Kitty placement API) and answers the program's
terminal queries. `ghostty_vt_test` runs in the Nix check on both platforms;
`ghostty_live_shell_test` runs the account's real startup on the host. Two
traps: flake.lock pins libghostty-vt 2026-07-20, whose `ghostty_terminal_new`
takes an options struct (newer releases take cols and rows), so the header was
checked declaration by declaration against the pinned release and the loader
refuses any other version; and LuaJIT forbids entering a Lua callback from an
FFI call made by compiled code, so the functions that call `vt_write` stay
interpreted. PNG payloads are "decoded" to a blank image of the declared size;
the runner checks placement, not pixels.

Its first finding: mandelbash ended every row with `ESC [ m ESC (` and no
final byte, so after the last row the terminal took the next printable
character as the charset designation and swallowed it: the first character
of the prompt after a mandelbash intro, or of whatever followed it at a
prompt. It surfaced as an intermittent failure because the gate rounds then
chose picks at random; they now force each pick in turn. mandelbash and
mandelroc now end rows with `ESC ( B` (select ASCII), as tput sgr0 does.

Original notes: current PTY tests use `expect` and see only the byte stream. nixpkgs ships `libghostty-vt`
(`0.1.0-unstable-2026-08-06`, outputs `out` and `dev`, cached for
x86_64-linux and aarch64-darwin). Plan: a LuaJIT runner opens a PTY, starts
the real shell in a fixture home, feeds every byte into a libghostty-vt
terminal through the FFI, answers terminal queries as Ghostty would, and
asserts on the rendered screen: the intro precedes a usable prompt, a typed
command's output appears, image placements arrive only where a protocol is
supported, and no stray escape bytes reach the screen.

## Open questions

- `.shellenv` is still unsourced and `BASH_ENV` is unwired (see
  `CODE_REVIEW.md`). The Lua engine could become what `.shellenv` runs; decide
  before wiring non-interactive startup.
- One clean TTY-less interactive startup took 6.3 s once and then about 0.5 s on six
  repeats (2026-11-27). The cold cost was not attributed; watch for recurrence.
- `set +h` disables command hashing, so every command typed at the prompt walks
  the 167-entry PATH. Not a startup cost, but worth revisiting with PATH order.

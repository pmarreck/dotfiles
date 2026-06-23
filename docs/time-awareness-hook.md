# Giving Claude Code a sense of time (rate-limited, low-noise)

A self-contained recipe. Read this one file and you can reproduce the whole
mechanism from scratch — a human or another LLM, knowing nothing else.

---

## 1. The problem

An LLM agent has **no clock**. It only knows what is in its context window.
So:

- Inject a timestamp on *every* action → the context fills with noise.
- Inject one *once* at session start → it goes stale within minutes.

The goal is to inject timestamps at a **human-like cadence**: frequent enough
that the agent stays oriented in time (and notices the *passage* of time — e.g.
"that build took 40 minutes"), but sparse enough to be almost invisible.

## 2. The delivery mechanism

Claude Code **hooks** are external commands the harness runs on certain events.
A hook can print a line of JSON of this shape:

```json
{"hookSpecificOutput":{"hookEventName":"<event>","additionalContext":"⏱ ..."}}
```

The `additionalContext` string is **injected into the model's context**. That is
the entire delivery channel: the hook prints that line, the model sees the
timestamp on its next think.

- Verified working on **Claude Code 2.1.177**.
- Every hook receives a JSON object on **stdin** that includes `session_id` and
  `hook_event_name` (plus event-specific fields).
- `additionalContext` injection works for both `UserPromptSubmit` and
  `PostToolUse` events (the two we use).

## 3. The design (what makes it useful *and* quiet)

### Two hooks, two cadences
Wire the **same** script into two events:

- **`UserPromptSubmit`** — fires once per user turn → tracks the **human's**
  cadence (a fresh stamp each time you talk to the agent).
- **`PostToolUse`** — fires after each tool call → tracks time during long
  **autonomous** runs when the human isn't typing.

Both call one script which is internally **rate-limited**, so the vast majority
of `PostToolUse` invocations print *nothing*. That is what makes it cheap to
leave enabled on every tool call.

### The rate-limiter (mimics glancing at a clock)
The script emits one of three things:

- **long** — `⏱ Monday, June 23, 2026 10:27 PM EDT` — the **first** emit of each
  wall-clock hour.
- **short** — `⏱ 10:33 PM EDT` — when **more than 5 minutes** have passed since
  the last short emit.
- **none** — silent, otherwise.

A **long emit also resets the short timer**, so you never get a long immediately
echoed by a short.

### Why it is a pure function
The decision is a pure function of four numbers, with **no I/O** — which makes it
trivially testable:

```
decide(now_epoch, now_hourkey, last_hourkey, last_short_epoch):
  if   now_hourkey != last_hourkey        -> long   (new state: now_hourkey, now_epoch)   # incl. first run
  elif (now_epoch - last_short) > 300      -> short  (new state: last_hourkey, now_epoch)
  else                                     -> none   (state unchanged)
```

`hourkey` is `date +%Y%m%d%H` — so a new hour, a new day, or "24h later, same
hour" all register as a new hour.

## 4. Where the parts live

| Part | Path |
|---|---|
| The script (executable) | `~/bin/time-awareness-hook` (here: a symlink into `~/dotfiles/bin/`) |
| The tests | `~/dotfiles/bin/test/time-awareness-hook_test` |
| The wiring | `~/.claude/settings.json` → `hooks` |
| Per-session state | `${XDG_STATE_HOME:-~/.local/state}/claude-time-awareness/state-<session_id>` |

State is **per session** (keyed on the hook's `session_id`), so concurrent
sessions don't interfere; the state file is two lines (`hourkey` then
`last_short_epoch`). Stale state files (>1 day) are pruned on each long emit.

## 5. Implement it (3 steps)

### Step 1 — install the script
Save the following as an executable on your `PATH` (e.g. `~/bin/time-awareness-hook`),
then `chmod +x` it.

```bash
#!/usr/bin/env bash
# time-awareness-hook — emit a rate-limited human timestamp so Claude Code stays
# aware of wall-clock time and its passage (it has no clock; it only knows what
# lands in context). Wired into ~/.claude/settings.json as a UserPromptSubmit
# and/or PostToolUse hook; the emitted JSON's additionalContext is injected into
# the model's context.
#
# Cadence (mimics how a human glances at a clock): emit the LONG form (weekday +
# full date + time) the first time per wall-clock hour, the SHORT form (just the
# time) when MORE than 5 minutes have passed since the last short, and nothing
# otherwise. A LONG emit also resets the short timer so you never get a long
# immediately echoed by a short.
#
# Architecture is hexagonal: a PURE decision core (`--decide`, no I/O) decides
# none|short|long from (now_epoch, now_hourkey, last_hourkey, last_short_epoch);
# the adapter supplies those from the clock + a per-session state file and emits.
# Test seams (env): TIMESTAMP_HOOK_NOW (epoch override), TIMESTAMP_HOOK_STATE_DIR,
# TIMESTAMP_HOOK_SESSION. State lives under XDG_STATE_HOME, one file per session.
set -u

SHORT_INTERVAL=300   # seconds; "more than 5 minutes" => strict > this

# --- pure core -------------------------------------------------------------
# decide NOW_EPOCH NOW_HOURKEY LAST_HOURKEY LAST_SHORT_EPOCH
# prints: "<emit> <new_hourkey> <new_short_epoch>"  (emit in none|short|long)
_decide() {
	local now_epoch="$1" now_hourkey="$2" last_hourkey="$3" last_short="${4:-0}"
	if [ "$now_hourkey" != "$last_hourkey" ]; then
		printf 'long %s %s\n' "$now_hourkey" "$now_epoch"          # new hour (incl. first run)
	elif [ $(( now_epoch - last_short )) -gt "$SHORT_INTERVAL" ]; then
		printf 'short %s %s\n' "$last_hourkey" "$now_epoch"        # >5 min since last short
	else
		printf 'none %s %s\n' "$last_hourkey" "$last_short"        # too soon; state unchanged
	fi
}

# --- adapter helpers -------------------------------------------------------
# portable epoch -> formatted string (GNU date first, BSD date fallback)
_fmt() { date -d "@$1" +"$2" 2>/dev/null || date -r "$1" +"$2"; }

# pull a top-level string field out of the hook's stdin JSON
_json_get() {
	local json="$1" key="$2"
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$json" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
	else
		printf '%s' "$json" | grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
			| head -1 | sed -E "s/.*:[[:space:]]*\"([^\"]*)\"/\1/"
	fi
}

_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_'; }

_usage() {
	cat <<'EOF'
time-awareness-hook — rate-limited timestamp injection for Claude Code

USAGE
  time-awareness-hook                 # hook mode: reads hook JSON on stdin, emits
                                      # additionalContext JSON (or nothing) on stdout
  time-awareness-hook --decide NOW HOURKEY LAST_HOURKEY LAST_SHORT
                                      # pure core: prints "<none|short|long> <hourkey> <short_epoch>"
  time-awareness-hook -h | --help
  time-awareness-hook --about
  time-awareness-hook --test          # run test suite (stdout muted; exit = #fails)

CADENCE
  long  : first emit of each wall-clock hour (weekday, full date, time)
  short : when > 5 min since the last short (just the time)
  none  : otherwise (silent)
  A long emit resets the short timer.

ENV (test seams)
  TIMESTAMP_HOOK_NOW         epoch-seconds override for "now"
  TIMESTAMP_HOOK_STATE_DIR   state directory (default: $XDG_STATE_HOME/claude-time-awareness)
  TIMESTAMP_HOOK_SESSION     session id fallback when stdin lacks one
EOF
}

# --- hook mode -------------------------------------------------------------
_hook_main() {
	# never block waiting on a tty when run by hand with no stdin
	local input=""
	if [ ! -t 0 ]; then input="$(cat)"; fi

	local session event
	session="$(_json_get "$input" session_id)"
	event="$(_json_get "$input" hook_event_name)"
	[ -n "$session" ] || session="${TIMESTAMP_HOOK_SESSION:-default}"
	[ -n "$event" ] || event="UserPromptSubmit"

	local now state_dir state_file
	now="${TIMESTAMP_HOOK_NOW:-$(date +%s)}"
	state_dir="${TIMESTAMP_HOOK_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-time-awareness}"
	mkdir -p "$state_dir" 2>/dev/null || true
	state_file="$state_dir/state-$(_safe "$session")"

	local now_hourkey last_hourkey="" last_short="0"
	now_hourkey="$(_fmt "$now" '%Y%m%d%H')"
	if [ -f "$state_file" ]; then
		{ read -r last_hourkey; read -r last_short; } < "$state_file" 2>/dev/null || true
		[ -n "$last_short" ] || last_short="0"
	fi

	local emit new_hourkey new_short
	read -r emit new_hourkey new_short < <(_decide "$now" "$now_hourkey" "$last_hourkey" "$last_short")

	[ "$emit" = "none" ] && return 0

	# persist new state atomically (only on an actual emit)
	local tmp="$state_file.tmp.$$"
	printf '%s\n%s\n' "$new_hourkey" "$new_short" > "$tmp" 2>/dev/null && mv -f "$tmp" "$state_file" 2>/dev/null

	# hourly housekeeping: drop state files older than a day (cheap, runs ~once/hour)
	[ "$emit" = "long" ] && find "$state_dir" -maxdepth 1 -type f -name 'state-*' -mtime +0 -delete 2>/dev/null

	local stamp
	case "$emit" in
		long)  stamp="$(_fmt "$now" '⏱ %A, %B %d, %Y %I:%M %p %Z')" ;;
		short) stamp="$(_fmt "$now" '⏱ %I:%M %p %Z')" ;;
	esac
	printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$stamp"
}

# --- dispatch --------------------------------------------------------------
case "${1:-}" in
	-h|--help)   _usage; exit 0 ;;
	--about)     echo "time-awareness-hook: rate-limited timestamp injection for Claude Code ($(uname -s) $(uname -m))"; exit 0 ;;
	--decide)    shift; _decide "$@"; exit 0 ;;
	--test)
		_tf="$HOME/dotfiles/bin/test/time-awareness-hook_test"
		if [ -f "$_tf" ]; then exec bash "$_tf" >/dev/null; fi
		echo "no test file at $_tf" >&2; exit 0 ;;
	*)           _hook_main; exit 0 ;;
esac
```

> Note: the bash function bodies are **tab-indented**. If you copy/paste, keep
> the tabs (or it still runs — bash doesn't care — but match your house style).

### Step 2 — wire it into Claude Code
Edit `~/.claude/settings.json` (user-global) — or a project's
`.claude/settings.json` — and **merge** this `hooks` object in. If a `hooks`
object already exists, add these two keys to it; do **not** clobber sibling hooks.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "$HOME/bin/time-awareness-hook" } ] }
    ],
    "PostToolUse": [
      { "hooks": [ { "type": "command", "command": "$HOME/bin/time-awareness-hook" } ] }
    ]
  }
}
```

- Omitting `"matcher"` on `PostToolUse` matches **all** tools (fine — it's
  rate-limited). Add `"matcher": "Bash"` (etc.) to scope it to specific tools.
- Use `$HOME/bin/...` (not a bare name) for portability across machines.
- **The effect is immediate — no session restart needed.**

### Step 3 — verify
```bash
# Long form (first call of the hour for a fresh session):
printf '{"hook_event_name":"PostToolUse","session_id":"demo"}' \
  | TIMESTAMP_HOOK_STATE_DIR="$(mktemp -d)" ~/bin/time-awareness-hook
# -> {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"⏱ Monday, June 23, 2026 10:27 PM EDT"}}
```
In a live session you'll then see lines like `⏱ 10:33 PM EDT` appear in the
agent's context — long once per hour, short after >5 min, silent otherwise.

## 6. The test suite (proves the cadence; optional but recommended)

Save as `~/dotfiles/bin/test/time-awareness-hook_test` and run it directly
(`bash time-awareness-hook_test`) — it exits with the number of failures. It
tests the pure core at every boundary (first run, the exactly-300s vs 301s line,
the hour-rollover override) and the adapter with an **injected clock** and an
isolated temp state dir, so it's fully deterministic.

```bash
#!/usr/bin/env bash
# Tests for time-awareness-hook: rate-limited timestamp injection for Claude time cognizance.
#
# Architecture under test is hexagonal: a PURE decision core (`--decide`) that takes
# (now_epoch, now_hourkey, last_hourkey, last_short_epoch) and emits one of none|short|long
# plus the new state — no clock, no state file, no stdin. The hook adapter (default mode)
# reads stdin JSON + clock + state and calls that same core. We test the pure core directly
# (deterministic, no I/O) and exercise the adapter with an injected clock + temp state dir.
#
# Conventions: progress -> stdout, failures -> stderr, exit code == number of failures.
# NEVER use set -e here (error paths are under test); set -u only.
set -u

HOOK="$HOME/dotfiles/bin/time-awareness-hook"
tests=0
fails=0

expect_eq() { # actual expected msg
	((tests++))
	if [ "$1" = "$2" ]; then
		echo "✓ $3"
	else
		echo "✗ $3" >&2
		echo "    expected: [$2]" >&2
		echo "    actual:   [$1]" >&2
		((fails++))
	fi
}
expect_contains() { # haystack needle msg
	((tests++))
	if printf '%s' "$1" | grep -q -- "$2"; then echo "✓ $3"
	else echo "✗ $3" >&2; echo "    [$1] lacks [$2]" >&2; ((fails++)); fi
}
expect_not_contains() { # haystack needle msg
	((tests++))
	if printf '%s' "$1" | grep -q -- "$2"; then echo "✗ $3" >&2; echo "    [$1] unexpectedly has [$2]" >&2; ((fails++))
	else echo "✓ $3"; fi
}

# portable epoch->format (GNU first, BSD fallback) so expectations match the hook
fmt() { date -d "@$1" +"$2" 2>/dev/null || date -r "$1" +"$2"; }

# ---- PURE CORE: time-awareness-hook --decide now_epoch now_hourkey last_hourkey last_short ----
emit()  { "$HOOK" --decide "$@" | cut -d' ' -f1; }
state() { "$HOOK" --decide "$@" | cut -d' ' -f2-; }

echo "# pure decision core"
# 1. first run (empty prior hour) -> long, short reset to now
expect_eq "$(emit 1000000000 2026062221 '' 0)" "long"                       "first run -> long"
expect_eq "$(state 1000000000 2026062221 '' 0)" "2026062221 1000000000"     "first run state = nowhour + now"
# 2. same hour, 100s since short -> none
expect_eq "$(emit 1000000100 2026062221 2026062221 1000000000)" "none"      "same hour <5min -> none"
# 3. same hour, exactly 300s -> none (rule is 'MORE than 5 min', strict >)
expect_eq "$(emit 1000000300 2026062221 2026062221 1000000000)" "none"      "exactly 5min -> none (strict)"
# 4. same hour, 301s -> short, updates short epoch, keeps hour
expect_eq "$(emit 1000000301 2026062221 2026062221 1000000000)" "short"     "just over 5min -> short"
expect_eq "$(state 1000000301 2026062221 2026062221 1000000000)" "2026062221 1000000301" "short keeps hour, bumps short epoch"
# 5. hour changed but short was 10s ago -> long overrides + resets short timer
expect_eq "$(emit 1000000010 2026062222 2026062221 1000000000)" "long"      "hour change overrides recent short"
expect_eq "$(state 1000000010 2026062222 2026062221 1000000000)" "2026062222 1000000010" "long resets short epoch to now"

# ---- ADAPTER: full stdin/state path with injected clock + isolated state dir ----
echo "# hook adapter (injected clock + temp state)"
# --tmpdir places this in $TMPDIR (RAM); per project convention it self-cleans,
# and avoiding an explicit rm dodges the rm-safe wrapper's noise on teardown.
TMP="$(mktemp -d --tmpdir time-awareness-hook.XXXXXX)"
run() { # now_epoch session
	printf '{"hook_event_name":"PostToolUse","session_id":"%s"}' "$2" \
		| TIMESTAMP_HOOK_NOW="$1" TIMESTAMP_HOOK_STATE_DIR="$TMP" "$HOOK"
}
WD="$(fmt 1000000000 %A)"   # weekday name only appears in the LONG format

# 6. fresh session -> long emit (JSON additionalContext, weekday present) + state file created
o6="$(run 1000000000 sessA)"
expect_contains     "$o6" "additionalContext" "fresh session emits additionalContext JSON"
expect_contains     "$o6" "$WD"               "fresh session emit is LONG (weekday present)"
expect_eq "$([ -f "$TMP/state-sessA" ] && echo yes)" "yes" "state file created for session"
# 7. same session 2 min later, same hour -> none (silent)
expect_eq "$(run 1000000120 sessA)" "" "2 min later same hour -> no output"
# 8. same session ~6.5 min later -> short (time present, weekday absent)
o8="$(run 1000000400 sessA)"
expect_contains     "$o8" "additionalContext" "6+ min later emits"
expect_not_contains "$o8" "$WD"               "6+ min emit is SHORT (no weekday)"
# 9. session isolation: a different session id is fresh -> long, separate state file
o9="$(run 1000000400 sessB)"
expect_contains     "$o9" "$WD"               "different session is independent -> LONG"
expect_eq "$([ -f "$TMP/state-sessB" ] && echo yes)" "yes" "separate state file per session"

# ---- summary ----
if [ "$fails" -gt 0 ]; then
	echo "$fails of $tests tests FAILED" >&2
else
	echo "all $tests tests passed"
fi
exit "$fails"
```

## 7. Requirements & portability

- **Bash** + **`date`** (GNU `date -d @epoch` is tried first, BSD `date -r epoch`
  is the fallback — so it works on both Linux and macOS).
- **`jq`** is used if present; otherwise a `grep`/`sed` fallback parses the two
  fields we need from the stdin JSON. So **jq is optional**.
- A **Claude Code** recent enough to inject `hookSpecificOutput.additionalContext`
  for `UserPromptSubmit` / `PostToolUse` (confirmed on **2.1.177**).

## 8. Why these specific choices (design notes)

- **Two hooks** because the human and the agent move on different clocks: a user
  turn is the human's heartbeat; a tool call is the agent's. Covering both means
  the agent is oriented whether you're driving or it's running autonomously.
- **Rate-limiting in the script, not the wiring**, so `PostToolUse` can stay on
  *every* tool with negligible cost — it returns instantly with no output the
  vast majority of the time.
- **Long-hourly / short->5min / silent** mirrors how people actually track time:
  you register the hour when it rolls over, and you're vaguely aware of ~5-minute
  chunks in between. The long-emit-resets-short rule prevents a redundant short
  right after a long.
- **The pure `--decide` core** (no clock, no files, no stdin) is the part worth
  lifting into any agent harness — it's what makes the cadence testable with an
  injected clock, and it's language-agnostic (port the 3-line rule anywhere).
- **Per-session state** keyed on `session_id` keeps concurrent agent sessions
  from stomping each other's timers.

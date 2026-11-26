# Herdr project layout and conversation identity

`erect-agent-stack` creates an `AI` tab and a separate `CLI` shell at the
project root. Rejoining a live agent preserves its custom tabs. When an exited
agent leaves two shells in the same directory, the unique single-pane `AI`
tab disambiguates the launch target. Multiple AI candidates remain an error.

The `herdr-codex-session-hook` replaces unsafe environment-only SessionStart
reporting. A shared Codex app-server may retain the Herdr pane environment of
the client that started it, while serving other conversations. Consequently,
`HERDR_PANE_ID` alone cannot establish the current conversation's terminal.

The hook requires an exact native resume ID in one foreground Codex process,
matching the event's session ID and working directory, before publishing a
Herdr resume recipe. It never types input, restarts an agent or launches a new
conversation. Malformed, fresh, `--last`, differently mapped and ambiguous
reports are ignored. This deliberately sacrifices automatic reporting when
independent identity evidence is unavailable; it does not fix provider-side
environment propagation. Explicit native IDs remain necessary when restoring
those unreported conversations.

The launcher stores conversation identity in `erect-agent-stack/v2` records.
`requested_session_id` preserves the operator's exact resume target,
`observed_session_id` records what Herdr reports, and
`verified_session_id` is set only after the backend, pane, ready lifecycle
state, and native ID agree. The legacy `session_id` field aliases the verified
ID for compatibility. Existing v1 records remain readable and migrate after
the next verified launch.

Every launch attempt receives one read-only post-start inspection, including
attempts whose `agent start` command times out. A ready agent with the exact
native ID can therefore finish successfully without a duplicate launch. A
missing ID, mismatched ID, blocked update/login UI, unknown state, or malformed
response leaves an `unconfirmed` record and exits 69. The saved requested ID
remains available for a later explicit or automatic exact retry.

Install the command `"$HOME/dotfiles/bin/herdr-codex-session-hook"` as the
Codex SessionStart hook instead of the stock Herdr integration. Clients that
cache the old hook command may need a restart or a temporary redirect in that
managed hook. Back up both files first. Reinstalling Herdr's integration can
replace its managed file or hook registration, so recheck this guard after
integration updates. It requires Bash, jq, and Herdr on PATH.

Identity repairs use Herdr's public reporting API with a current sequence and
`--session-start-source resume`; changing an already recorded identity without
that transition marker can be ignored. Verify the resulting agent record and
saved session file. Back up the topology first, and do not edit the live
session JSON behind the daemon.

The shell tests exercise the process/event classifier and recorded reporting
effects without touching a real terminal. Launcher tests cover new tab names,
AI-shell selection, ambiguous layouts, preservation of live agents, timeout
reinspection, blocked startup, ID mismatch, and record migration. Both run
under `./test`.

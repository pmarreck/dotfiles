# Auditing destructive commands

`kill`, `pkill`, and `chmod` record target details before making changes.
If the audit directory cannot be created or written, the shadows refuse the
unaudited action. Logs are private to the current user under
`${TMPDIR:-/tmp}/dotfiles-audit-${EUID}/`. Use the same `TMPDIR` to retrieve
them. The system can clear them on reboot or through temporary-file cleanup.
Process command lines in these logs can contain private arguments.

| Command | Effect |
| --- | --- |
| `kill --log` or `pkill --log` | Read the shared process signal history. |
| `chmod --log` | Read per-target permission changes and their batch IDs. |
| `chmod --undo` | Restore modes changed by the newest completed, unrestored batch. |
| `chmod --undo JOURNAL-ID` | Restore a specific completed batch listed by `--log`. |
| `rm-safe --undo` | Restore the newest recoverable Trash entry. Also available as `rm --undo` through the Trash shadow. |
| `rm-safe --log` | Read the Trash action log, newest first. Also available as `rm --log` through the Trash shadow. |

The Bash startup files load the `kill` function before the builtin and export
it to child Bash shells. Use the dotfiles executable by its path in shells
that still resolve `kill` to a builtin. The function can resolve a Bash
jobspec in its original shell.
For group signals, the wrapper snapshots current group members. The
whole-system broadcast selector `-1` has no fixed auditable process group.

`pkill` uses the platform's `pgrep` selectors and signals the logged PIDs.
Ancestor protection is on by default. `--allow-ancestors` is an explicit
override. Both signal shadows recheck process identity before signaling.
The snapshot and signal are separate system operations, and a process may
exit or be replaced in between. A signal entry records the request and any
observed delivery result. It cannot restore process state.

Recursive `chmod` reads the tree first, then visits each child before changing
its containing directory. The traversal uses the platform default or an
explicit `-H`, `-L`, or `-P`. Undo restores directory access first and checks
that the pathname still identifies the logged object and has the expected
mode. It reports skipped targets and leaves them eligible for a later retry.
The journal tracks Unix mode bits. Use an ACL-aware backup for macOS ACL edits.
An interrupted batch without a completion marker retains its pre-change log
for manual recovery.

When invoking a native command directly or using an operation without a
shadow, independently log the exact targets and their prior state before
proceeding. Save enough detail to identify what was affected and to recover
when the operation supports recovery.

#!/usr/bin/env bash

steam-procs() {
  PS_PERSONALITY=linux ps -eo pid,args | tail -n +2 | awk -v filter="steam" 'tolower($0) ~ filter && $0 !~ " awk " && $0 !~ "/ipcserver"' | sort -nr
}
export -f steam-procs

steam-pids() {
  steam-procs | cut -d ' ' -f 1
}
export -f steam-pids

steam-kill() {
  steam-procs > /dev/stderr
  steam-pids | xargs -I {} kill $1 {}
}
export -f steam-kill

kill-steam-proton-pids() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # This bash one-liner performs the following tasks:
  # 1. It sets the PS_PERSONALITY environment variable to 'linux' which standardizes the output format of the 'ps' command.
  # 2. Runs the 'ps' command with the following options:
  #    - 'e' to include processes from all users,
  #    - 'o pid,args' to only show process ID and command arguments,
  #    - '--sort=-pid' to sort by process ID in descending order (so it kills the newest processes first),
  #      (unavailable on macOS so used 'sort -nr' instead)
  #    - '--no-headers' to not include column headers in the output. (unavailable on macOS so used 'tail -n +2' instead)
  # 3. It pipes this output to 'awk', an underrated text-stream-oriented scripting language,
  #    where it checks if the string 'steam' (case-insensitive) is present in any of the lines.
  # 4. It also filters out the 'awk' command itself and the 'ipcserver' process, which is Steam-related.
  # 5. Pipes the output to another command (cut -d ' ' -f 1) which prints only the first column (the process ID).
  # 6. Finally, it pipes these process IDs to 'xargs' which executes the 'kill' command for each ID, terminating the processes.
  steam-kill
  sleep 2 # give it a chance to seppuku
  # This usually leaves ~2 processes running still, which we now kill with extreme prejudice. You had your chance.
  steam-kill -9
  echo "Steam is now fragged."
}
export -f kill-steam-proton-pids

#!/usr/bin/env bash

function kill-steam-proton-pids() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # This bash one-liner performs the following tasks:
  # 1. It sets the PS_PERSONALITY environment variable to 'linux' which standardizes the output format of the 'ps' command.
  # 2. Runs the 'ps' command with the following options:
  #    - 'e' to include processes from all users,
  #    - 'o pid,args' to only show process ID and command arguments,
  #    - '--sort=-pid' to sort by process ID in descending order (so it kills the newest processes first),
  #    - '--no-headers' to not include column headers in the output.
  # 3. It pipes this output to 'awk', a scripting language used for manipulating data and generating reports,
  #    where it checks if the string 'steam' (case-insensitive) is present in any of the lines.
  # 4. It then pipes this filtered output to 'tail -n +2' to ignore the first line (the awk filtering process itself).
  # 5. Pipes the output to another 'awk' command which prints only the first column (the process ID).
  # 6. Finally, it pipes these process IDs to 'xargs' which executes the 'kill' command for each ID, terminating the processes.
  function killit() {
    PS_PERSONALITY=linux ps -eo pid,args --no-headers | awk -v filter="steam" 'tolower($0) ~ filter && $0 !~ " awk "' | tee /dev/stderr | awk '{print $1}' | xargs -I {} kill $1 {}
  }
  killit
  sleep 2 # give it a chance to seppuku
  # This usually leaves ~2 processes running still, which we now kill with extreme prejudice. You had your chance.
  killit -9
  echo "Steam is now fragged."
}

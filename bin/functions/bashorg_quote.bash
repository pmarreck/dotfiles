#!/usr/bin/env bash

bashorg_quote() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  # Extract quote data from bashorg_quotes.tsv in the same directory as this script
  local script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  local quotes_file="$script_dir/bashorg_quotes_unwrapped.tsv"
  if [[ ! -f "$quotes_file" ]]; then
    echo "Error: quotes file '$quotes_file' not found." >&2
    return 1
  fi
  # Use awk to process the data, sort by score, and select a random quote
  awk -F'\t' '
    BEGIN { srand() }
    {
      score = $2 + 10;
      quotes[NR] = $0;
      total += score;
      scores[NR] = total;
    }
    END {
      random_num = int(rand() * total);
      for (i = 1; i <= NR; i++) {
        if (scores[i] >= random_num) {
          split(quotes[i], fields, "\t");
          gsub(/\\n/, "\n", fields[3]);
          print fields[3];
          exit;
        }
      }
    }
  ' "$quotes_file"
}

# if this script is sourced, return; otherwise it will run the function
return 0 2>/dev/null || bashorg_quote

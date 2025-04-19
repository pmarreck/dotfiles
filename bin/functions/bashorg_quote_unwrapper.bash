gawk -F'\t' -v OFS='\t' 'function is_username(line) {
  # Match <username>, (username), [username], username: (word with colon+space), * , *** or a bracketed timestamp
  return line ~ /^((<[^>]{1,30}>)|(\([^\)]{1,30}\))|(\[[^\]]{1,30}\])|([A-Za-z_^\|\[\]`\\\-][A-Za-z0-9_^\|\[\]`\\\-]{1,30} ?: )|(\* )|(\*\*\*)|\[[0-9]{1,2}:[0-9]{1,2}(:[0-9]{1,2})?:?((a|p)m?)?\])/
}
{
  quote = $3
  n = split(quote, parts, /\\n/)
  out = parts[1]
  mode = 1
  for (i = 2; i <= n; i++) {
    after = parts[i]
    split(after, lines, "\n")
    firstline = lines[1]
    if (mode == 1) {
      if (length(parts[i-1]) >= 50 && !is_username(firstline)) {
        out = out " " parts[i]
        mode = 2
        continue
      } else {
        out = out "\\n" parts[i]
        mode = 1
        continue
      }
    } else {
      if (!is_username(firstline)) {
        out = out " " parts[i]
        continue
      } else {
        out = out "\\n" parts[i]
        mode = 1
        continue
      }
    }
  }
  $3 = out
  print
}' bashorg_quotes.tsv > bashorg_quotes_unwrapped.tsv

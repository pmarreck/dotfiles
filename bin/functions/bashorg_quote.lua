#!/usr/bin/env luajit
math.randomseed(os.time())
local get_script_dir
get_script_dir = function()
  local src = debug.getinfo(2, "S").source
  if src:match("^@") then
    return src:match("^@(.-)[^/]+$")
  else
    return "./"
  end
end
local parse_quotes
parse_quotes = function(filename)
  local quotes = { }
  local total_score = 0
  for line in io.lines(filename) do
    local _continue_0 = false
    repeat
      local id, score, quote = line:match("^(%d+)\t(%d+)\t(.+)$")
      if not (id and score and quote) then
        _continue_0 = true
        break
      end
      score = tonumber(score)
      total_score = total_score + (score + 10)
      table.insert(quotes, {
        score = score + 10,
        quote = quote,
        cumulative = total_score
      })
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return quotes, total_score
end
local pick_quote
pick_quote = function(quotes, total_score)
  local r = math.random(total_score)
  for _index_0 = 1, #quotes do
    local q = quotes[_index_0]
    if q.cumulative >= r then
      return q.quote:gsub("\\n", "\n")
    end
  end
end
local main
main = function()
  local script_dir = get_script_dir()
  local quotes_file = script_dir .. "bashorg_quotes.tsv"
  local quotes, total = parse_quotes(quotes_file)
  return print((pick_quote(quotes, total)))
end
return main()

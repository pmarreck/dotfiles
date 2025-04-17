#!/usr/bin/env moon
math.randomseed os.time!

get_script_dir = ->
	src = debug.getinfo(2, "S").source
	if src\match "^@"
		return src\match("^@(.-)[^/]+$") -- extract path prefix
	else
		return "./"

parse_quotes = (filename) ->
	quotes = {}
	total_score = 0

	for line in io.lines filename
		id, score, quote = line\match("^(%d+)\t(%d+)\t(.+)$")
		continue unless id and score and quote

		score = tonumber score
		total_score += score + 10
		table.insert quotes, {
			score: score + 10
			quote: quote
			cumulative: total_score
		}

	quotes, total_score

pick_quote = (quotes, total_score) ->
	r = math.random total_score
	for q in *quotes
		if q.cumulative >= r
			return q.quote\gsub("\\n", "\n")

main = ->
	script_dir = get_script_dir!
	quotes_file = script_dir .. "bashorg_quotes.tsv"
	quotes, total = parse_quotes quotes_file
	print (pick_quote quotes, total)

main!

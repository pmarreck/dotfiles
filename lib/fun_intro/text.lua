-- Pure text picks for the terminal intro. Each takes its data as a string and
-- a random source, so tests can force any choice. Each reproduces what the
-- Bash or awk command it replaced printed, including the final newline.
--
-- rng.int(n) returns an integer in 1..n; rng.unit() returns a real in [0, 1).
local wrap = require("fun_intro.wrap")

local M = {}

-- Records as awk and shuf split them: on "\n", without an empty record after a
-- final newline.
function M.records(text)
	local out, start = {}, 1
	while start <= #text do
		local stop = text:find("\n", start, true)
		if not stop then
			out[#out + 1] = text:sub(start)
			break
		end
		out[#out + 1] = text:sub(start, stop - 1)
		start = stop + 1
	end
	return out
end

-- Field `n` of a record split on single-character separator `sep`, as awk -F.
local function field(record, sep, n)
	local index, start = 1, 1
	while true do
		local stop = record:find(sep, start, true)
		if index == n then return record:sub(start, stop and stop - 1 or nil) end
		if not stop then return "" end
		index, start = index + 1, stop + 1
	end
end

-- awk's string-to-number: the longest leading decimal number, else 0.
local function awk_number(s)
	local text = s:match("^[ \t\n]*([-+]?%d*%.?%d*[eE][-+]?%d+)") or s:match("^[ \t\n]*([-+]?%d*%.?%d*)")
	return tonumber(text) or 0
end

local function awk_int(x)
	return x >= 0 and math.floor(x) or math.ceil(x)
end

-- warhammer_quote: a random non-blank line plus "!".
function M.warhammer(text, rng)
	local quotes = {}
	for _, line in ipairs(M.records(text)) do
		if not line:match("^%s*$") then quotes[#quotes + 1] = line end
	end
	return quotes[rng.int(#quotes)] .. "!\n"
end

-- One chuck record as `cut -d'|' -f2- | fold -s -w WIDTH` prints it. `locale`
-- holds fold's character rules, or nil for bytes (see wrap.lua).
function M.chuck_format(line, width, locale)
	local bar = line:find("|", 1, true)
	if bar then line = line:sub(bar + 1) end
	return wrap.fold_spaces(line .. "\n", width, locale)
end

-- chuck: `shuf -n 1 | cut -d'|' -f2- | fold -s -w WIDTH`.
function M.chuck(text, rng, width, locale)
	local lines = M.records(text)
	return M.chuck_format(lines[rng.int(#lines)], width, locale)
end

-- bashorg_quote: weighted by score + 10 over a TSV of id, score, quote, with
-- the original awk's selection rule (the first running total reaching
-- int(rand() * total)) and its "\n" unescaping. Only the third field prints.
-- The file is about 5 MB, so records are located by offset and only the
-- chosen one is copied.
function M.bashorg(text, rng)
	local starts, stops, totals, total = {}, {}, {}, 0
	local position, length, count = 1, #text, 0
	while position <= length do
		local stop = (text:find("\n", position, true) or length + 1) - 1
		count = count + 1
		starts[count], stops[count] = position, stop
		local score = 0
		local tab = text:find("\t", position, true)
		if tab and tab <= stop then
			local next_tab = text:find("\t", tab + 1, true)
			local score_text = text:sub(tab + 1, (next_tab and next_tab <= stop) and next_tab - 1 or stop)
			score = score_text:find("^%d+$") and tonumber(score_text) or awk_number(score_text)
		end
		total = total + score + 10
		totals[count] = total
		position = stop + 2
	end
	local target = awk_int(rng.unit() * total)
	for i = 1, count do
		if totals[i] >= target then
			local record = text:sub(starts[i], stops[i])
			return (field(record, "\t", 3):gsub("\\n", "\n")) .. "\n"
		end
	end
	return ""
end

-- just_one_taoup: a random non-empty line with the last "---" header above it.
function M.taoup(text, rng)
	local lines, headers, header = {}, {}, ""
	for _, line in ipairs(M.records(text)) do
		if line:match("^%-%-%-") then
			header = line
		elseif line ~= "" then
			lines[#lines + 1] = line
			headers[#lines] = header
		end
	end
	local index = awk_int(rng.unit() * #lines) + 1
	return headers[index] .. "\n" .. lines[index] .. "\n"
end

-- bc's `scale=50; a / b` for positive integers: exact long division,
-- truncated (not rounded) to 50 decimal places, without a leading zero below 1.
function M.bc_divide(a, b, scale)
	local whole = math.floor(a / b)
	local remainder = a - whole * b
	local digits = {}
	for i = 1, scale do
		remainder = remainder * 10
		local digit = math.floor(remainder / b)
		digits[i] = digit
		remainder = remainder - digit * b
	end
	local integer = whole == 0 and "" or string.format("%.0f", whole)
	return integer .. "." .. table.concat(digits)
end

-- times_older_than_samson: age ratio at `now` (seconds), birthdays at local
-- midnight as `date -d YYYY-MM-DD` reads them.
function M.samson(now)
	local peter = os.time({ year = 1972, month = 4, day = 5, hour = 0 })
	local samson = os.time({ year = 2021, month = 6, day = 25, hour = 0 })
	return "Peter, you are " .. M.bc_divide(now - peter, now - samson, 50) .. " times older than Samson.\n"
end

-- asciidragon: green dragon art, exactly as the heredoc trimmer printed it.
M.DRAGON = "\27[0;32m\n" .. [==[
                 ___====-_  _-====___
           _--~~~#####//      \\#####~~~--_
        _-~##########// (    ) \\##########~-_
       -############//  :\^^/:  \\############-
     _~############//   (@::@)   \\############~_
    ~#############((     \\//     ))#############~
   -###############\\    (^^)    //###############-
  -#################\\  / "" \  //#################-
 -###################\\/      \//###################-
_#/:##########/\######(   /\   )######/\##########:\#_
:/ :#/\#/\#/\/  \#/\##\  :  :  /##/\#/  \/\#/\#/\#: \:
"  :/  V  V  "   V  \#\: :  : :/#/  V   "  V  V  \:  "
   "   "  "      "   \ : :  : : /   "      "  "   "
]==] .. "\27[0m\n"

return M

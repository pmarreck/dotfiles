-- GNU `fold -s -w WIDTH`, byte for byte, for wrapping intro text.
--
-- Columns follow GNU fold: a tab advances to the next multiple of 8,
-- backspace steps back one, carriage return resets to 0. In a UTF-8 locale
-- fold 9.x measures each character by its display width (wide characters 2,
-- combining marks 0), counts each invalid byte as 1, and breaks at any
-- Unicode blank; pass those rules as `locale` = { width = fn(code point),
-- blank = fn(code point) }. Without it every byte counts 1 and only space and
-- tab are blanks, as in the C locale. When a character would pass WIDTH, the
-- line breaks after its last blank if it has one, otherwise right there.
local M = {}

-- Split text into characters: valid UTF-8 sequences when `utf8`, else bytes.
-- Each entry is the character's bytes and its code point (nil when invalid).
local function characters(text, utf8)
	local chars, points = {}, {}
	local i, n = 1, #text
	while i <= n do
		local b = text:byte(i)
		local length, point = 1, nil
		if utf8 and b >= 0xC2 and b <= 0xF4 then
			local need = b >= 0xF0 and 3 or b >= 0xE0 and 2 or 1
			local value = b % (need == 1 and 32 or need == 2 and 16 or 8)
			local valid = i + need <= n
			for k = 1, need do
				local c = valid and text:byte(i + k)
				if not c or c < 0x80 or c > 0xBF then valid = false; break end
				value = value * 64 + c % 64
			end
			-- Reject overlong forms, surrogates, and values past U+10FFFF.
			if valid and not ((need == 2 and value < 0x800) or (need == 3 and value < 0x10000)
				or (value >= 0xD800 and value <= 0xDFFF) or value > 0x10FFFF) then
				length, point = need + 1, value
			end
		elseif utf8 and b < 0x80 then
			point = b
		end
		chars[#chars + 1] = text:sub(i, i + length - 1)
		points[#chars] = point
		i = i + length
	end
	return chars, points
end

function M.fold_spaces(text, width, locale)
	local chars, points = characters(text, locale ~= nil)
	local function advance(column, k)
		local c = chars[k]
		if c == "\b" then return column > 0 and column - 1 or 0 end
		if c == "\r" then return 0 end
		if c == "\t" then return column + 8 - column % 8 end
		if locale and points[k] then return column + locale.width(points[k]) end
		return column + 1
	end

	local out, line = {}, {} -- line holds character indexes
	local column = 0
	local k, n = 1, #chars
	while k <= n do
		if chars[k] == "\n" then
			local parts = {}
			for j = 1, #line do parts[j] = chars[line[j]] end
			out[#out + 1] = table.concat(parts) .. "\n"
			line, column = {}, 0
			k = k + 1
		else
			local next_column = advance(column, k)
			if next_column > width then
				local blank
				for j = #line, 1, -1 do
					local c, point = chars[line[j]], points[line[j]]
					if c == " " or c == "\t" or (locale and point and locale.blank(point)) then blank = j; break end
				end
				if blank then
					local parts = {}
					for j = 1, blank do parts[j] = chars[line[j]] end
					out[#out + 1] = table.concat(parts) .. "\n"
					local rest = {}
					for j = blank + 1, #line do rest[#rest + 1] = line[j] end
					line, column = rest, 0
					for j = 1, #line do column = advance(column, line[j]) end
					-- Reconsider this character against the shortened line.
				elseif #line == 0 then
					line[1] = k
					column = next_column
					k = k + 1
				else
					local parts = {}
					for j = 1, #line do parts[j] = chars[line[j]] end
					out[#out + 1] = table.concat(parts) .. "\n"
					line, column = {}, 0
					-- Reconsider this character at the start of the next line.
				end
			else
				line[#line + 1] = k
				column = next_column
				k = k + 1
			end
		end
	end
	if #line > 0 then
		local parts = {}
		for j = 1, #line do parts[j] = chars[line[j]] end
		out[#out + 1] = table.concat(parts)
	end
	return table.concat(out)
end

return M

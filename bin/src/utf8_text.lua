local M = {}

local function continuation(byte)
	return byte and byte >= 0x80 and byte <= 0xBF
end

function M.codepoints(text)
	local result = {}
	local index = 1
	local length = #text

	while index <= length do
		local first = text:byte(index)
		local width
		local second = text:byte(index + 1)

		if first <= 0x7F then
			width = 1
		elseif first >= 0xC2 and first <= 0xDF
			and continuation(second) then
			width = 2
		elseif first == 0xE0 and second and second >= 0xA0
			and second <= 0xBF and continuation(text:byte(index + 2)) then
			width = 3
		elseif first >= 0xE1 and first <= 0xEC
			and continuation(second) and continuation(text:byte(index + 2)) then
			width = 3
		elseif first == 0xED and second and second >= 0x80
			and second <= 0x9F and continuation(text:byte(index + 2)) then
			width = 3
		elseif first >= 0xEE and first <= 0xEF
			and continuation(second) and continuation(text:byte(index + 2)) then
			width = 3
		elseif first == 0xF0 and second and second >= 0x90
			and second <= 0xBF and continuation(text:byte(index + 2))
			and continuation(text:byte(index + 3)) then
			width = 4
		elseif first >= 0xF1 and first <= 0xF3
			and continuation(second) and continuation(text:byte(index + 2))
			and continuation(text:byte(index + 3)) then
			width = 4
		elseif first == 0xF4 and second and second >= 0x80
			and second <= 0x8F and continuation(text:byte(index + 2))
			and continuation(text:byte(index + 3)) then
			width = 4
		else
			return nil, string.format("invalid UTF-8 at byte %d", index)
		end

		result[#result + 1] = text:sub(index, index + width - 1)
		index = index + width
	end

	return result
end

function M.has_whitespace(codepoints)
	for _, character in ipairs(codepoints) do
		local bytes = {character:byte(1, #character)}
		local value
		if #bytes == 1 then
			value = bytes[1]
		elseif #bytes == 2 then
			value = (bytes[1] - 0xC0) * 0x40 + bytes[2] - 0x80
		elseif #bytes == 3 then
			value = (bytes[1] - 0xE0) * 0x1000
				+ (bytes[2] - 0x80) * 0x40 + bytes[3] - 0x80
		else
			value = (bytes[1] - 0xF0) * 0x40000
				+ (bytes[2] - 0x80) * 0x1000
				+ (bytes[3] - 0x80) * 0x40 + bytes[4] - 0x80
		end

		if (value >= 0x09 and value <= 0x0D) or value == 0x20
			or value == 0x85 or value == 0xA0 or value == 0x1680
			or (value >= 0x2000 and value <= 0x200A)
			or value == 0x2028 or value == 0x2029 or value == 0x202F
			or value == 0x205F or value == 0x3000 then
			return true
		end
	end
	return false
end

return M

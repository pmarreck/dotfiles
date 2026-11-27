-- Graphics escape streams for the intro's pre-rendered image, so startup needs
-- no ImageMagick. Kitty output reproduces display_image's framing exactly:
-- base64 PNG in 4096-character chunks, `a=T,f=100` on the first, `m=1` on
-- every chunk but the last, then a newline. Sixel output is the pre-rendered
-- stream unchanged.
local ffi = require("ffi")

local M = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local CHUNK = 4096

-- Standard base64 with padding.
function M.base64(data)
	local n = #data
	local out = ffi.new("uint8_t[?]", math.floor((n + 2) / 3) * 4 + 1)
	local input = ffi.cast("const uint8_t *", data)
	local alphabet = ffi.cast("const uint8_t *", ALPHABET)
	local o = 0
	for i = 0, n - 3, 3 do
		local word = input[i] * 65536 + input[i + 1] * 256 + input[i + 2]
		out[o] = alphabet[math.floor(word / 262144)]
		out[o + 1] = alphabet[math.floor(word / 4096) % 64]
		out[o + 2] = alphabet[math.floor(word / 64) % 64]
		out[o + 3] = alphabet[word % 64]
		o = o + 4
	end
	local tail = n % 3
	if tail > 0 then
		local i = n - tail
		local word = input[i] * 65536 + (tail == 2 and input[i + 1] * 256 or 0)
		out[o] = alphabet[math.floor(word / 262144)]
		out[o + 1] = alphabet[math.floor(word / 4096) % 64]
		out[o + 2] = tail == 2 and alphabet[math.floor(word / 64) % 64] or 61 -- "="
		out[o + 3] = 61
		o = o + 4
	end
	return ffi.string(out, o)
end

function M.kitty(png)
	local encoded = M.base64(png)
	local length = #encoded
	if length <= CHUNK then
		return "\27_Ga=T,f=100;" .. encoded .. "\27\\\n"
	end
	local parts, offset = {}, 1
	while offset <= length do
		local chunk = encoded:sub(offset, offset + CHUNK - 1)
		local last = offset + CHUNK - 1 >= length
		if offset == 1 then
			parts[#parts + 1] = "\27_Ga=T,f=100,m=1;" .. chunk .. "\27\\"
		elseif last then
			parts[#parts + 1] = "\27_Gm=0;" .. chunk .. "\27\\"
		else
			parts[#parts + 1] = "\27_Gm=1;" .. chunk .. "\27\\"
		end
		offset = offset + CHUNK
	end
	return table.concat(parts) .. "\n"
end

-- Width and height of a PNG from its IHDR chunk, or nil.
function M.png_size(png)
	if png:sub(1, 8) ~= "\137PNG\r\n\26\n" or png:sub(13, 16) ~= "IHDR" then return nil end
	local function u32(at)
		local a, b, c, d = png:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end

return M

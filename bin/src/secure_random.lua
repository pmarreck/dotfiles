local M = {}

local UINT32_RANGE = 4294967296

local function decode_u32(bytes)
	return bytes:byte(1) * 0x1000000
		+ bytes:byte(2) * 0x10000
		+ bytes:byte(3) * 0x100
		+ bytes:byte(4)
end

function M.sample_index(read_four, upper_bound)
	if type(upper_bound) ~= "number" or upper_bound % 1 ~= 0
		or upper_bound < 1 or upper_bound > UINT32_RANGE then
		return nil, "sample bound must be an integer from 1 through 2^32"
	end

	local accepted_range = math.floor(UINT32_RANGE / upper_bound) * upper_bound
	while true do
		local bytes, read_error = read_four()
		if not bytes then
			return nil, read_error or "random source ended before four bytes were read"
		end
		if #bytes ~= 4 then
			return nil, "random source ended before four bytes were read"
		end
		local value = decode_u32(bytes)
		if value < accepted_range then
			return value % upper_bound + 1
		end
	end
end

function M.open_reader(path)
	local file, open_error = io.open(path, "rb")
	if not file then
		return nil, string.format("cannot open random source %s: %s", path, open_error)
	end

	local function read_four()
		local bytes = file:read(4)
		if not bytes or #bytes ~= 4 then
			return nil, string.format("random source %s ended before four bytes were read", path)
		end
		return bytes
	end

	return read_four, file
end

return M

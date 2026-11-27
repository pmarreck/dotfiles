-- The intro's random source: math.random seeded once from /dev/urandom, so
-- shells started in the same second still choose differently (awk's srand()
-- seeded from the clock's seconds).
local M = {}

function M.seeded()
	local seed
	local file = io.open("/dev/urandom", "rb")
	if file then
		local bytes = file:read(4)
		file:close()
		if bytes and #bytes == 4 then
			local a, b, c, d = bytes:byte(1, 4)
			seed = ((a * 256 + b) * 256 + c) * 256 + d
		end
	end
	math.randomseed(seed or (os.time() + math.floor(os.clock() * 1000000)))
	return {
		int = function(n) return math.random(n) end,
		unit = function() return math.random() end,
	}
end

return M

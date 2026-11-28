-- mandelbash stays a Bash demo, but its output is fully deterministic (a
-- fixed 80x13 render, mirrored), so the intro memoizes it. The cache key is a
-- hash of the script's bytes, so editing the script renders anew. Writes are
-- atomic and a failed render leaves no file behind.
local ffi = require("ffi")
local bit = require("bit")

local M = {}

-- 64-bit FNV-1a of a string, as 16 hex digits.
function M.fnv1a64(data)
	local hash = ffi.new("uint64_t", 0xcbf29ce484222325ULL)
	local prime = ffi.new("uint64_t", 0x100000001b3ULL)
	for i = 1, #data do
		hash = bit.bxor(hash, data:byte(i)) * prime
	end
	return bit.tohex(hash, 16)
end

-- The render is cached in one file whose first line names the script version
-- it came from (FNV-1a of the script's text). A new version overwrites it, so
-- renders of old versions never pile up.
-- `fs` provides read(path), ensure_dir(dir), write_atomic(path, data), and
-- run(path) returning output, exit status. Returns the output (cached or
-- fresh) or nil, message. An unwritable cache still returns fresh output.
function M.output(script_path, cache_dir, fs)
	local script = fs.read(script_path)
	if not script then return nil, "mandelbash not found at " .. script_path end
	local cache_path = cache_dir .. "/mandelbash"
	local stamp = "# mandelbash " .. M.fnv1a64(script) .. "\n"
	local cached = fs.read(cache_path)
	if cached and #cached > #stamp and cached:sub(1, #stamp) == stamp then return cached:sub(#stamp + 1) end

	local output, status = fs.run(script_path)
	if status ~= 0 or not output or #output == 0 then
		return nil, "mandelbash failed with status " .. tostring(status)
	end
	if fs.ensure_dir(cache_dir) then fs.write_atomic(cache_path, stamp .. output) end
	return output
end

return M

local cjson = require("cjson")
if cjson.encode_empty_table_as_object then cjson.encode_empty_table_as_object(false) end

local function table_is_array(value)
	local count, maximum = 0, 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
		count = count + 1
		if key > maximum then maximum = key end
	end
	return count == maximum
end

local function encode_canonical(value)
	local value_type = type(value)
	if value == cjson.null then return "null" end
	if value_type == "nil" then return "null" end
	if value_type == "boolean" then return value and "true" or "false" end
	if value_type == "number" then return cjson.encode(value) end
	if value_type == "string" then return cjson.encode(value) end
	if value_type ~= "table" then
		error("cannot encode JSON value of type " .. value_type)
	end
	if table_is_array(value) then
		local encoded = {}
		for index = 1, #value do encoded[index] = encode_canonical(value[index]) end
		return "[" .. table.concat(encoded, ",") .. "]"
	end
	local keys = {}
	for key in pairs(value) do
		if type(key) ~= "string" then error("JSON object key must be a string") end
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local encoded = {}
	for _, key in ipairs(keys) do
		encoded[#encoded + 1] = cjson.encode(key) .. ":" .. encode_canonical(value[key])
	end
	return "{" .. table.concat(encoded, ",") .. "}"
end

--- Build the persistence adapter around an injected filesystem/process port.
local function new(runtime)
	local M = {}

	function M.encode_json(value)
		return encode_canonical(value)
	end

	function M.decode_json(value)
		return cjson.decode(value)
	end

	function M.load_json_file(path)
		local contents = runtime.read_file(path)
		if contents == nil then return nil end
		local ok, value = pcall(cjson.decode, contents)
		if not ok then return nil, "invalid JSON snapshot: " .. path end
		return value, nil, contents
	end

	function M.write_atomic(path, contents)
		return runtime.write_atomic(path, contents)
	end

	--- Decide whether a visible report warrants a refresh without host I/O.
	function M.publication_due(now_epoch, atime_epoch, mtime_epoch, weekly_seconds)
		local week = weekly_seconds or (7 * 24 * 60 * 60)
		now_epoch = tonumber(now_epoch)
		atime_epoch = tonumber(atime_epoch)
		mtime_epoch = tonumber(mtime_epoch)
		if not atime_epoch or not mtime_epoch then return true, "missing" end
		if not now_epoch or now_epoch < mtime_epoch then return true, "clock-skew" end
		if atime_epoch > mtime_epoch then return true, "viewed" end
		if now_epoch - mtime_epoch >= week then return true, "weekly" end
		return false, "unread"
	end

	function M.file_times(path)
		return runtime.file_times(path)
	end

	--- Rotate current into previous and publish the new complete snapshot.
	function M.persist_snapshot(state_dir, snapshot)
		local current_path = state_dir .. "/current.json"
		local previous_path = state_dir .. "/previous.json"
		local previous, load_err, previous_bytes = M.load_json_file(current_path)
		if load_err then return nil, load_err end
		if previous_bytes then
			local ok, err = M.write_atomic(previous_path, previous_bytes)
			if not ok then return nil, err end
		end
		local ok, err = M.write_atomic(current_path, M.encode_json(snapshot) .. "\n")
		if not ok then return nil, err end
		return previous
	end

	--- Exclude concurrent snapshot/report publishers with portable atomic mkdir.
	function M.acquire_state_lock(state_dir)
		local _, state_ok =
			runtime.run_command("mkdir -p " .. runtime.shell_quote(state_dir))
		if not state_ok then return nil, "cannot create state directory: " .. state_dir end
		local lock_path = state_dir .. "/.fleet-status.lock"
		local _, locked = runtime.run_command("mkdir " .. runtime.shell_quote(lock_path))
		if not locked then return nil, "fleet-status state is locked by another run" end
		return lock_path
	end

	function M.release_state_lock(lock_path)
		local _, released = runtime.run_command("rmdir " .. runtime.shell_quote(lock_path))
		if not released then return nil, "cannot release fleet-status state lock" end
		return true
	end

	return M
end

return { new = new }

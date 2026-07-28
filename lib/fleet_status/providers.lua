local cjson = require("cjson")

--- Construct the external-provider adapter with response caching around
--- injected process and state ports.
local function new(runtime, state, network_cache_version)
	local M = {}
	local cache

	function M.configure_cache(options)
		cache = options
	end

	function M.command(environment_name, fallback, arguments)
		local executable = os.getenv(environment_name) or fallback
		local timeout = os.getenv("FLEET_STATUS_TIMEOUT")
		if not timeout then
			local discovered, found =
				runtime.run_command("command -v gtimeout || command -v timeout")
			timeout = found and runtime.trim(discovered) or nil
		end
		if not timeout or timeout == "" then return "false" end
		local seconds = tonumber(os.getenv("FLEET_STATUS_PROVIDER_TIMEOUT_SECONDS")) or 30
		seconds = math.max(1, math.floor(seconds))
		return runtime.shell_quote(timeout) .. " " .. tostring(seconds) .. " "
			.. runtime.shell_quote(executable) .. " " .. arguments
	end

	function M.decode_json(command)
		local cache_path
		if cache and cache.ttl_seconds > 0 then
			local hash = 5381
			for index = 1, #command do
				hash = (hash * 33 + command:byte(index)) % 4294967296
			end
			cache_path = cache.directory .. "/" .. string.format("%08x", hash) .. ".json"
			local record = state.load_json_file(cache_path)
			local record_ttl = record and record.negative
				and math.min(cache.ttl_seconds, 900)
				or cache.ttl_seconds
			if record
				and record.network_cache_version == network_cache_version
				and record.command == command
				and tonumber(record.cached_at_epoch)
				and cache.now_epoch - tonumber(record.cached_at_epoch) <= record_ttl then
				return record.response
			end
		end
		local output, ok = runtime.run_command(command)
		local decoded_ok, decoded = pcall(cjson.decode, output)
		if not ok or not decoded_ok then
			if cache_path and cache.save then
				state.write_atomic(cache_path, state.encode_json({
					network_cache_version = network_cache_version,
					command = command,
					cached_at_epoch = cache.now_epoch,
					negative = true,
					response = cjson.null,
				}) .. "\n")
			end
			return nil
		end
		if cache_path and cache.save then
			state.write_atomic(cache_path, state.encode_json({
				network_cache_version = network_cache_version,
				command = command,
				cached_at_epoch = cache.now_epoch,
				response = decoded,
			}) .. "\n")
		end
		return decoded
	end

	return M
end

return { new = new }

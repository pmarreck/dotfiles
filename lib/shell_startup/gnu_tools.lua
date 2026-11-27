-- GNU-preferred tool paths for startup (SED, DATE, TAC, SHUF, STAT,
-- TIMEOUT), ported from bin/src/export_gnu_tool.bash, which stays as the
-- oracle. That helper ran `CANDIDATE --version | head -1` for every
-- candidate on every startup. Here each answer is cached under the
-- candidate's resolved path, its name (coreutils is one multicall binary
-- behind many names), and the file's size and mtime, so a startup after the
-- first runs none.
local M = {}

M.TOOLS = {
	{ "SED", "sed", "gsed" },
	{ "DATE", "date", "gdate" },
	{ "TAC", "tac", "gtac" },
	{ "SHUF", "shuf", "gshuf" },
	{ "STAT", "stat", "gstat" },
	{ "TIMEOUT", "timeout", "gtimeout" },
}

-- Executables named `name` in PATH order, as `type -a -p` lists them.
local function candidates(name, path_value, fs)
	local found = {}
	for dir in ((path_value or "") .. ":"):gmatch("([^:]*):") do
		local candidate = (dir == "" and "." or dir) .. "/" .. name
		if fs.is_executable(candidate) then found[#found + 1] = candidate end
	end
	return found
end
M.candidates = candidates

-- The first of them, which is what the shell runs for `name`, without
-- scanning the rest of PATH.
function M.first_candidate(name, path_value, fs)
	for dir in ((path_value or "") .. ":"):gmatch("([^:]*):") do
		local candidate = (dir == "" and "." or dir) .. "/" .. name
		if fs.is_executable(candidate) then return candidate end
	end
	return nil
end

-- A version probe with a persistent cache. `run(candidate)` returns the first
-- line of `candidate --version`; `store` has read() -> text or nil and
-- write(text). Returns probe(candidate) and save().
function M.cached_probe(fs, run, store)
	local entries = {}
	for line in ((store.read() or "") .. "\n"):gmatch("([^\n]*)\n") do
		local key, stamp, version = line:match("^([^\t]+)\t([^\t]+)\t(.*)$")
		if key then entries[key] = { stamp = stamp, version = version } end
	end
	local dirty = false
	local function probe(candidate)
		local real = fs.realpath(candidate) or candidate
		local key = real .. "|" .. (candidate:match("([^/]+)$") or candidate)
		local stamp = fs.stat_key(real)
		local hit = entries[key]
		if stamp and hit and hit.stamp == stamp then return hit.version end
		local version = (run(candidate) or ""):gsub("[\t\r\n]", " ")
		if stamp then
			entries[key] = { stamp = stamp, version = version, live = true }
			dirty = true
		end
		return version
	end
	-- Rewrites the cache when it learned something, dropping entries whose
	-- files are gone (test runs leave temporary paths behind).
	local function save()
		if not dirty then return end
		local lines = {}
		for key, entry in pairs(entries) do
			local real = key:match("^(.*)|[^|]*$")
			if entry.live or fs.stat_key(real) == entry.stamp then
				lines[#lines + 1] = key .. "\t" .. entry.stamp .. "\t" .. entry.version
			end
		end
		table.sort(lines)
		store.write(table.concat(lines, "\n") .. "\n")
	end
	return probe, save
end

-- The first candidate, across `names` in order and each in PATH order, whose
-- version line says GNU, without skipping dotfiles wrappers: what the login
-- profile's sed loop chose (`for c in $(type -a -p gsed) $(type -a -p sed)`).
-- Returns nil when none does.
function M.first_gnu(names, path_value, fs, probe)
	for _, name in ipairs(names) do
		for _, candidate in ipairs(candidates(name, path_value, fs)) do
			if probe(candidate):find("GNU", 1, true) then return candidate end
		end
	end
	return nil
end

-- Resolve every tool not already set in the environment. Returns the
-- assignments ({name, path} in TOOLS order) and the messages the Bash helper
-- printed on stderr.
function M.resolve(env, path_value, home, fs, probe)
	local assignments, messages = {}, {}
	local wrappers = home .. "/dotfiles/bin/"
	local function is_wrapper(candidate)
		local canonical = fs.realpath(candidate) or candidate
		return canonical:sub(1, #wrappers) == wrappers
	end
	for _, tool in ipairs(M.TOOLS) do
		local var, plain, g_prefix = tool[1], tool[2], tool[3]
		if env(var) == nil then
			local chosen
			for _, candidate in ipairs(candidates(g_prefix, path_value, fs)) do
				if probe(candidate):find("GNU", 1, true) then chosen = candidate; break end
			end
			local plains = candidates(plain, path_value, fs)
			if not chosen then
				for _, candidate in ipairs(plains) do
					if not is_wrapper(candidate) and probe(candidate):find("GNU", 1, true) then
						chosen = candidate
						break
					end
				end
			end
			if not chosen then
				for _, candidate in ipairs(plains) do
					if not is_wrapper(candidate) then
						chosen = candidate
						if (env("MUTE_GNU_WRAPPER_WARNINGS") or "") == "" then
							messages[#messages + 1] = string.format("\27[38;5;208mwarning: no GNU %s found on PATH; "
								.. "falling back to %s (set MUTE_GNU_WRAPPER_WARNINGS=1 to silence)\27[0m", plain, candidate)
						end
						break
					end
				end
			end
			if chosen then
				assignments[#assignments + 1] = { var, chosen }
			else
				messages[#messages + 1] = "Error: no " .. plain .. " or " .. g_prefix .. " found in PATH"
			end
		end
	end
	return assignments, messages
end

return M

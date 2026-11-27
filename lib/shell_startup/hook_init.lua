-- Init scripts for the prompt hooks bin/apply-hooks evaluates (direnv, mcfly,
-- starship). Running the three tools for them took about 21 ms on every
-- interactive startup. Each script depends only on the tool binary, the path
-- it was found at, and its arguments (ghostty_live_shell_test compares the
-- cache with live output on every host), so it is cached in a file named by a
-- hash of the invoked path, resolved path, size, mtime, and arguments. Files
-- are written once and never changed in place, so a shell reading one cannot
-- see another shell's write. Starship's own init is a stub that evaluates
-- `starship init bash --print-full-init`; caching the full init also saves
-- that second run.
local ffi = require("ffi")
local bit = require("bit")
local gnu_tools = require("gnu_tools")

local M = {}

-- { variable suffix, command name, arguments }. The arguments are constants:
-- they are spliced into a shell command line unquoted.
M.HOOKS = {
	{ "DIRENV", "direnv", "hook bash" },
	{ "MCFLY", "mcfly", "init bash" },
	{ "STARSHIP", "starship", "init bash --print-full-init" },
}

function M.fnv1a64(data)
	local hash = ffi.new("uint64_t", 0xcbf29ce484222325ULL)
	local prime = ffi.new("uint64_t", 0x100000001b3ULL)
	for i = 1, #data do
		hash = bit.bxor(hash, data:byte(i)) * prime
	end
	return bit.tohex(hash, 16)
end

local function quote(text)
	return "'" .. text:gsub("'", "'\\''") .. "'"
end

-- Runs `name args` as the shell would: found on `path_value`, with argv[0]
-- the bare name (starship embeds the path it finds that way). A prefix
-- assignment both steers sh's lookup (dash and bash use it) and reaches the
-- command's environment. stderr passes through. Returns the output, or nil
-- when the command fails or prints nothing.
function M.run(name, args, path_value)
	local pipe = io.popen("PATH=" .. quote(path_value) .. " " .. name .. " " .. args .. "; printf '\\036%d' \"$?\"")
	if not pipe then return nil end
	local output = pipe:read("*a") or ""
	pipe:close()
	local text, status = output:match("^(.*)\030(%d+)$")
	if status ~= "0" or text == "" then return nil end
	return text
end

-- Cache files for `name` other than `keep`, removed after a new one lands so
-- upgrades do not accumulate scripts. A shell that loses its file to this
-- falls back to running the tool.
local function prune(cache_dir, name, keep, fs)
	for _, entry in ipairs(fs.list_dir(cache_dir) or {}) do
		if entry ~= keep and entry:match("^" .. name .. "%-%x+%.bash$") then
			os.remove(cache_dir .. "/" .. entry)
		end
	end
end

-- Assignments ({name, value}) naming, for each hook tool on `path_value`, the
-- path the shell will run it by (SHELL_STARTUP_HOOK_<TOOL>_BIN) and its cached
-- init script (SHELL_STARTUP_HOOK_<TOOL>_INIT), then SHELL_STARTUP_HOOK_PATH,
-- the PATH searched: while the shell's PATH is still exactly that, apply-hooks
-- can trust these paths without searching a long PATH itself. A tool that is
-- absent, or whose init fails, gets neither, and apply-hooks runs it as before.
function M.resolve(path_value, cache_dir, fs, run)
	run = run or M.run
	local assignments = {}
	for _, hook in ipairs(M.HOOKS) do
		local var, name, args = hook[1], hook[2], hook[3]
		local bin = gnu_tools.first_candidate(name, path_value, fs)
		local real = bin and (fs.realpath(bin) or bin)
		local stamp = real and fs.stat_key(real)
		if stamp then
			local entry = name .. "-" .. M.fnv1a64(table.concat({ bin, real, stamp, args }, "\0")) .. ".bash"
			local file = cache_dir .. "/" .. entry
			local present = fs.stat_key(file) ~= nil
			if not present then
				local text = run(name, args, path_value)
				if text and fs.write_atomic(file, text) then
					present = true
					prune(cache_dir, name, entry, fs)
				end
			end
			if present then
				assignments[#assignments + 1] = { "SHELL_STARTUP_HOOK_" .. var .. "_BIN", bin }
				assignments[#assignments + 1] = { "SHELL_STARTUP_HOOK_" .. var .. "_INIT", file }
			end
		end
	end
	if #assignments > 0 then assignments[#assignments + 1] = { "SHELL_STARTUP_HOOK_PATH", path_value } end
	return assignments
end

return M

-- Terminal graphics facts for interactive shells, computed in the startup
-- engine instead of by forking check_sixel_support (infocmp, grep, ps) and
-- check_kitty_support from .profile. The rules are lib/fun_intro/terminal.lua,
-- tested against frozen copies of those probes.
--
--   SIXEL_ENV       the Sixel probe's verdict message
--   SIXEL_CAPABLE   true when Sixel is supported, else false
--   KITTY_CAPABLE   true when the Kitty graphics protocol is supported
--   IMAGE_CAPABLE   true when either is
--
-- SIXEL_ENV used to capture everything the probe pipeline wrote, including
-- infocmp's own complaint about an unknown TERM; now it is the message alone.
local terminal = require("fun_intro.terminal")
local terminfo = require("fun_intro.terminfo")

local M = {}

M.NAMES = { "SIXEL_ENV", "SIXEL_CAPABLE", "KITTY_CAPABLE", "IMAGE_CAPABLE" }

-- `env(name)` reads the environment, `read(path)` a file, and
-- `parent_command()` the command name of the shell's parent, the terminal
-- emulator for a new tab.
function M.facts(env, read, parent_command)
	local function terminfo_text()
		return terminfo.visible_text(terminfo.entry(env("TERM"), env, read))
	end
	local sixel_code, sixel_message = terminal.sixel(env, terminfo_text, parent_command)
	local kitty_code = terminal.kitty(env)
	local sixel, kitty = sixel_code == 0, kitty_code == 0
	return {
		SIXEL_ENV = sixel_message,
		SIXEL_CAPABLE = tostring(sixel),
		KITTY_CAPABLE = tostring(kitty),
		IMAGE_CAPABLE = tostring(sixel or kitty),
	}
end

-- Command name of a process as `ps -o comm=` prints it, without starting ps:
-- /proc/PID/comm on Linux; on macOS the process's argv[0], which ps reports
-- (read with the KERN_PROCARGS2 sysctl), else proc_name(3). Returns "" when
-- the process cannot be read.
function M.process_command(pid)
	pid = tonumber(pid)
	if not pid or pid <= 0 then return "" end
	local file = io.open("/proc/" .. pid .. "/comm", "rb")
	if file then
		local comm = file:read("*a") or ""
		file:close()
		return (comm:gsub("\n$", ""))
	end
	local ok, ffi = pcall(require, "ffi")
	if not ok or ffi.os ~= "OSX" then return "" end
	pcall(ffi.cdef, [[
		int proc_name(int pid, void *buffer, uint32_t buffersize);
		int sysctl(int *name, unsigned int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
	]])
	-- KERN_PROCARGS2 holds argc, the exec path, NUL padding, then argv.
	local mib = ffi.new("int[3]", 1, 49, pid) -- CTL_KERN, KERN_PROCARGS2
	local size = ffi.new("size_t[1]", 0)
	if ffi.C.sysctl(mib, 3, nil, size, nil, 0) == 0 and size[0] > 4 then
		local buffer = ffi.new("char[?]", size[0])
		if ffi.C.sysctl(mib, 3, buffer, size, nil, 0) == 0 then
			local args = ffi.string(buffer + 4, size[0] - 4)
			local argv0 = args:match("^[^%z]*%z+([^%z]+)")
			if argv0 then return argv0 end
		end
	end
	local name = ffi.new("char[256]")
	local length = ffi.C.proc_name(pid, name, 256)
	return length > 0 and ffi.string(name, length) or ""
end

return M

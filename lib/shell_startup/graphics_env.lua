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

-- Command name of a process without starting `ps`: /proc on Linux,
-- proc_name(3) on macOS. Returns "" when the process cannot be read.
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
	pcall(ffi.cdef, "int proc_name(int pid, void *buffer, uint32_t buffersize);")
	local buffer = ffi.new("char[256]")
	local length = ffi.C.proc_name(pid, buffer, 256)
	return length > 0 and ffi.string(buffer, length) or ""
end

return M

-- System adapters for the intro: files, atomic writes, PATH lookup, child
-- processes, terminal width, and parent processes. Everything the picks touch
-- outside Lua goes through here, so tests can substitute any of it.
local ffi = require("ffi")

ffi.cdef([[
	struct fun_intro_winsize { unsigned short row, col, xpixel, ypixel; };
	int ioctl(int fd, unsigned long request, ...);
	int mkdir(const char *path, unsigned int mode);
	int rename(const char *oldpath, const char *newpath);
	int unlink(const char *path);
	int access(const char *path, int mode);
	int getpid(void);
	int getppid(void);
	int wcwidth(int32_t c);
	int iswblank(uint32_t c);
]])

local M = {}

local IS_MAC = ffi.os == "OSX"
local TIOCGWINSZ = IS_MAC and 0x40087468 or 0x5413
local X_OK = 1

function M.read(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local data = file:read("*a")
	file:close()
	return data
end

-- mkdir -p without starting a process. Returns true when the directory exists.
function M.ensure_dir(path)
	local prefix = path:sub(1, 1) == "/" and "" or "."
	for part in path:gmatch("[^/]+") do
		prefix = prefix .. "/" .. part
		ffi.C.mkdir(prefix, 493) -- 0755; an existing directory is fine
	end
	local probe = io.open(path .. "/.", "rb")
	if probe then probe:close() return true end
	return false
end

-- Write through a unique temporary file and a rename, so readers never see a
-- partial file; on any failure the temporary file is removed.
function M.write_atomic(path, data)
	local temporary = path .. ".new." .. ffi.C.getpid()
	local file = io.open(temporary, "wb")
	if not file then return false end
	local ok = file:write(data)
	local closed = file:close()
	if ok and closed and ffi.C.rename(temporary, path) == 0 then return true end
	ffi.C.unlink(temporary)
	return false
end

-- The first executable `name` on `path_value`, as a shell would find it.
function M.find_command(name, path_value)
	for dir in ((path_value or "") .. ":"):gmatch("([^:]*):") do
		local candidate = (dir == "" and "." or dir) .. "/" .. name
		if ffi.C.access(candidate, X_OK) == 0 then
			local probe = io.open(candidate .. "/.", "rb")
			if probe then probe:close() else return candidate end
		end
	end
	return nil
end

local function shell_quote(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Run an executable with no arguments; returns its stdout and exit status.
-- LuaJIT's popen does not report the status, so the shell appends it.
function M.run(path)
	local pipe = io.popen(shell_quote(path) .. "; printf '\\036%d' \"$?\"", "r")
	if not pipe then return nil, 127 end
	local output = pipe:read("*a") or ""
	pipe:close()
	local body, status = output:match("^(.*)\030(%d+)$")
	if not body then return output, 127 end
	return body, tonumber(status)
end

-- Columns as `tput cols` reports them: COLUMNS, else the terminal on stdout,
-- stderr, or stdin, else 80.
function M.columns(env)
	local columns = tonumber(env("COLUMNS") or "")
	if columns and columns > 0 then return math.floor(columns) end
	local size = ffi.new("struct fun_intro_winsize")
	for _, fd in ipairs({ 1, 2, 0 }) do
		if ffi.C.ioctl(fd, TIOCGWINSZ, size) == 0 and size.col > 0 then return size.col end
	end
	return 80
end

-- GNU fold's character rules under the environment's LC_CTYPE (see
-- wrap.lua), or nil when that locale is not UTF-8 and fold counts bytes.
-- Characters wcwidth cannot measure count one column, as in fold.
function M.text_locale()
	local ctype = os.setlocale("", "ctype")
	if not ctype or not ctype:lower():find("utf%-?8") then return nil end
	return {
		width = function(point)
			local width = ffi.C.wcwidth(point)
			return width < 0 and 1 or width
		end,
		blank = function(point) return ffi.C.iswblank(point) ~= 0 end,
	}
end

-- Command name of process `pid`, as `ps -o comm= -p PID` prints it.
function M.process_command(pid)
	if not pid then return nil end
	if not IS_MAC then
		local comm = M.read("/proc/" .. pid .. "/comm")
		return comm and (comm:gsub("\n$", "")) or nil
	end
	local pipe = io.popen("ps -o comm= -p " .. math.floor(tonumber(pid) or 0) .. " 2>/dev/null")
	if not pipe then return nil end
	local comm = pipe:read("*a") or ""
	pipe:close()
	return (comm:gsub("%s+$", ""))
end

-- Parent of process `pid`.
function M.parent_of(pid)
	if not IS_MAC then
		local stat = M.read("/proc/" .. pid .. "/stat")
		-- The command name may contain spaces or parentheses; fields resume
		-- after the last ")".
		return stat and tonumber(stat:match(".*%)%s+%S+%s+(%d+)")) or nil
	end
	local pipe = io.popen("ps -o ppid= -p " .. math.floor(tonumber(pid) or 0) .. " 2>/dev/null")
	if not pipe then return nil end
	local ppid = tonumber((pipe:read("*a") or ""):match("%d+"))
	pipe:close()
	return ppid
end

function M.getppid() return ffi.C.getppid() end

return M

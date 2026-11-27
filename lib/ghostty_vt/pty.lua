-- A child process on a pseudo-terminal, through the LuaJIT FFI: forkpty for a
-- real controlling terminal, poll for bounded reads, TIOCSWINSZ for resizes.
local ffi = require("ffi")

ffi.cdef([[
	struct ghostty_vt_winsize { unsigned short row, col, xpixel, ypixel; };
	struct ghostty_vt_pollfd { int fd; short events; short revents; };
	int forkpty(int *amaster, char *name, void *termp, const struct ghostty_vt_winsize *winp);
	int execve(const char *path, char *const argv[], char *const envp[]);
	void _exit(int status);
	long read(int fd, void *buf, size_t count);
	long write(int fd, const void *buf, size_t count);
	int close(int fd);
	int poll(struct ghostty_vt_pollfd *fds, unsigned long nfds, int timeout);
	int waitpid(int pid, int *status, int options);
	int kill(int pid, int sig);
	int ioctl(int fd, unsigned long request, ...);
]])

local M = {}

local C = ffi.C
local POLLIN, WNOHANG, SIGHUP, SIGKILL = 1, 1, 1, 9
local TIOCSWINSZ = ffi.os == "OSX" and 0x80087467 or 0x5414

local function forkpty()
	local ok = pcall(function() return C.forkpty end)
	if ok then return C.forkpty end
	return ffi.load("util").forkpty -- glibc before 2.34 kept forkpty in libutil
end

local Process = {}
Process.__index = Process

-- Start `argv` (argv[1] is an absolute path) with exactly the environment
-- `env` (a list of "NAME=value") on a new terminal of `cols` x `rows`.
function M.spawn(argv, env, cols, rows)
	-- Everything the child touches is built before fork.
	local c_argv = ffi.new("char *[?]", #argv + 1)
	local keep = {}
	for i, value in ipairs(argv) do
		keep[#keep + 1] = ffi.new("char[?]", #value + 1, value)
		c_argv[i - 1] = keep[#keep]
	end
	local c_env = ffi.new("char *[?]", #env + 1)
	for i, value in ipairs(env) do
		keep[#keep + 1] = ffi.new("char[?]", #value + 1, value)
		c_env[i - 1] = keep[#keep]
	end
	local size = ffi.new("struct ghostty_vt_winsize", rows, cols, cols * 8, rows * 16)
	local master = ffi.new("int[1]")
	local pid = forkpty()(master, nil, nil, size)
	if pid == 0 then
		C.execve(c_argv[0], c_argv, c_env)
		C._exit(127)
	end
	assert(pid > 0, "forkpty failed")
	return setmetatable({ pid = pid, fd = master[0], keep = keep, exited = false }, Process)
end

-- Bytes available within `timeout_ms`: a string, "" on timeout, or nil once
-- the terminal has closed (the child and its descendants let go of it).
function Process:read(timeout_ms)
	local poll_fd = ffi.new("struct ghostty_vt_pollfd", self.fd, POLLIN, 0)
	local ready = C.poll(poll_fd, 1, timeout_ms)
	if ready <= 0 then return "" end
	local buffer = ffi.new("uint8_t[65536]")
	local count = C.read(self.fd, buffer, 65536)
	if count <= 0 then return nil end
	return ffi.string(buffer, count)
end

function Process:write(bytes)
	local offset = 0
	while offset < #bytes do
		local written = C.write(self.fd, ffi.cast("const char *", bytes) + offset, #bytes - offset)
		if written <= 0 then return false end
		offset = offset + written
	end
	return true
end

function Process:resize(cols, rows)
	local size = ffi.new("struct ghostty_vt_winsize", rows, cols, cols * 8, rows * 16)
	return C.ioctl(self.fd, TIOCSWINSZ, size) == 0
end

-- The exit status once the child has exited, else nil.
function Process:poll_exit()
	if self.exited then return self.status end
	local status = ffi.new("int[1]")
	if C.waitpid(self.pid, status, WNOHANG) == self.pid then
		self.exited, self.status = true, status[0]
	end
	return self.exited and self.status or nil
end

-- Hang up the terminal, as closing a tab does, and reap the child.
function Process:close()
	if not self.exited then
		C.kill(self.pid, SIGHUP)
		local status = ffi.new("int[1]")
		for _ = 1, 50 do
			if C.waitpid(self.pid, status, WNOHANG) == self.pid then self.exited = true; break end
			C.poll(nil, 0, 20)
		end
		if not self.exited then
			C.kill(self.pid, SIGKILL)
			C.waitpid(self.pid, status, 0)
			self.exited = true
		end
	end
	if self.fd then C.close(self.fd); self.fd = nil end
end

return M

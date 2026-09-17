#!/usr/bin/env luajit

local ffi = require("ffi")

ffi.cdef([[
typedef int pid_t;
typedef long ssize_t;
typedef unsigned long size_t;

struct winsize {
	unsigned short ws_row;
	unsigned short ws_col;
	unsigned short ws_xpixel;
	unsigned short ws_ypixel;
};

int openpty(int *master, int *slave, char *name, const void *termios,
	const struct winsize *winsize);
pid_t fork(void);
int dup2(int oldfd, int newfd);
int close(int fd);
ssize_t read(int fd, void *buffer, size_t count);
ssize_t write(int fd, const void *buffer, size_t count);
int execvp(const char *file, char *const argv[]);
int waitpid(pid_t pid, int *status, int options);
int ioctl(int fd, unsigned long request, ...);
char *strerror(int error_number);
void _exit(int status);
]])

local EINTR = 4
local EIO = 5
local TIOCGWINSZ = ffi.os == "Linux" and 0x5413 or 0x40087468
local pty_library = ffi.os == "OSX" and ffi.load("util") or ffi.C

local function fail(operation)
	local error_number = ffi.errno()
	io.stderr:write(string.format("timed: %s: %s\n", operation,
		ffi.string(ffi.C.strerror(error_number))))
	os.exit(126)
end

if #arg < 2 then
	io.stderr:write("timed: internal PTY adapter requires a terminal fd and command\n")
	os.exit(126)
end

local terminal_fd = tonumber(arg[1])
if not terminal_fd then
	io.stderr:write("timed: internal PTY adapter received an invalid terminal fd\n")
	os.exit(126)
end

local command_count = #arg - 1
local command_buffers = {}
local command_argv = ffi.new("char *[?]", command_count + 1)
for index = 1, command_count do
	local value = arg[index + 1]
	local buffer = ffi.new("char[?]", #value + 1)
	ffi.copy(buffer, value, #value)
	command_buffers[index] = buffer
	command_argv[index - 1] = buffer
end
command_argv[command_count] = nil

local master = ffi.new("int[1]")
local slave = ffi.new("int[1]")
local size = ffi.new("struct winsize[1]")
local size_pointer = nil
if ffi.C.ioctl(terminal_fd, TIOCGWINSZ, size) == 0 then
	size_pointer = size
end
if pty_library.openpty(master, slave, nil, nil, size_pointer) ~= 0 then
	fail("openpty")
end

local child = ffi.C.fork()
if child < 0 then
	fail("fork")
end
if child == 0 then
	ffi.C.close(master[0])
	if ffi.C.dup2(slave[0], 1) < 0 then
		ffi.C._exit(126)
	end
	if slave[0] ~= 1 then
		ffi.C.close(slave[0])
	end
	ffi.C.execvp(command_argv[0], command_argv)
	ffi.C._exit(127)
end

ffi.C.close(slave[0])

local buffer_size = 65536
local buffer = ffi.new("unsigned char[?]", buffer_size)
while true do
	local amount = ffi.C.read(master[0], buffer, buffer_size)
	if amount > 0 then
		local offset = 0
		local remaining = tonumber(amount)
		while remaining > 0 do
			local written = ffi.C.write(1, buffer + offset, remaining)
			if written < 0 then
				if ffi.errno() ~= EINTR then
					ffi.C.close(master[0])
					fail("write")
				end
			else
				local count = tonumber(written)
				offset = offset + count
				remaining = remaining - count
			end
		end
	elseif amount == 0 then
		break
	else
		local error_number = ffi.errno()
		if error_number ~= EINTR then
			if error_number ~= EIO then
				ffi.C.close(master[0])
				fail("read")
			end
			break
		end
	end
end
ffi.C.close(master[0])

local status = ffi.new("int[1]")
while ffi.C.waitpid(child, status, 0) < 0 do
	if ffi.errno() ~= EINTR then
		fail("waitpid")
	end
end

local wait_status = tonumber(status[0])
local signal_number = bit.band(wait_status, 0x7f)
if signal_number == 0 then
	os.exit(bit.band(bit.rshift(wait_status, 8), 0xff))
end
os.exit(128 + signal_number)

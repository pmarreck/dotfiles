-- Filesystem and collation facts for shell startup, through the LuaJIT FFI so
-- startup spawns no helper processes. Linux (glibc) and macOS are supported.
local ffi = require("ffi")
local bit = require("bit")

local M = {}

-- Offsets avoid declaring whole libc structs whose layouts differ by platform.
-- st_mode: Linux x86_64 stat {dev, ino, nlink, mode}; Linux arm64 stat
-- {dev, ino, mode}; macOS 64-bit-inode stat {int32 dev, uint16 mode}.
-- d_name: glibc dirent {ino, off, reclen, type, name}; macOS dirent
-- {ino, seekoff, reclen, namlen, type, name}.
-- st_size and st_mtime (seconds): Linux x86_64 and arm64 both place them at
-- 48 and 88; macOS arm64 at 96 and 48. They are left out where unverified
-- (macOS x64 may use the 32-bit-inode stat), which only disables caching.
local LAYOUTS = {
	["Linux/x64"] = { mode_offset = 24, mode_type = "uint32_t *", name_offset = 19, size_offset = 48, mtime_offset = 88 },
	["Linux/arm64"] = { mode_offset = 16, mode_type = "uint32_t *", name_offset = 19, size_offset = 48, mtime_offset = 88 },
	["OSX/arm64"] = { mode_offset = 4, mode_type = "uint16_t *", name_offset = 21, size_offset = 96, mtime_offset = 48 },
	["OSX/x64"] = { mode_offset = 4, mode_type = "uint16_t *", name_offset = 21 },
}
local layout = LAYOUTS[ffi.os .. "/" .. ffi.arch]
if not layout then
	error("shell_startup: unsupported platform " .. ffi.os .. "/" .. ffi.arch, 0)
end

ffi.cdef([[
	int stat(const char *path, void *buf);
	void *opendir(const char *name);
	void *readdir(void *dirp);
	int closedir(void *dirp);
	int strcoll(const char *a, const char *b);
	int access(const char *path, int mode);
	char *realpath(const char *path, char *resolved);
	void free(void *pointer);
	int mkdir(const char *path, unsigned int mode);
	int rename(const char *from, const char *to);
	int unlink(const char *path);
	int getpid(void);
]])

local S_IFMT, S_IFDIR = 0xF000, 0x4000
local stat_buffer = ffi.new("uint8_t[512]")

-- Same meaning as Bash `[ -d path ]`: stat follows symlinks, and no read or
-- search permission on the directory itself is required.
function M.is_dir(path)
	if path == "" or ffi.C.stat(path, stat_buffer) ~= 0 then return false end
	local mode = ffi.cast(layout.mode_type, stat_buffer + layout.mode_offset)[0]
	return bit.band(mode, S_IFMT) == S_IFDIR
end

-- Same meaning as Bash `[ -f path ] && [ -x path ]`, the test `type -a -p`
-- applies to PATH candidates: an executable regular file (after symlinks).
local S_IFREG = 0x8000
function M.is_executable(path)
	if path == "" or ffi.C.stat(path, stat_buffer) ~= 0 then return false end
	local mode = ffi.cast(layout.mode_type, stat_buffer + layout.mode_offset)[0]
	return bit.band(mode, S_IFMT) == S_IFREG and ffi.C.access(path, 1) == 0 -- X_OK
end

-- The canonical path with every symlink resolved, like `readlink -f`, or nil.
function M.realpath(path)
	local resolved = ffi.C.realpath(path, nil)
	if resolved == nil then return nil end
	local text = ffi.string(resolved)
	ffi.C.free(resolved)
	return text
end

-- "size:mtime" of a file (after symlinks), or nil where the stat layout is
-- unverified or the file cannot be read: a cache key that changes when a
-- binary is replaced.
function M.stat_key(path)
	if not layout.size_offset or ffi.C.stat(path, stat_buffer) ~= 0 then return nil end
	local size = ffi.cast("int64_t *", stat_buffer + layout.size_offset)[0]
	local mtime = ffi.cast("int64_t *", stat_buffer + layout.mtime_offset)[0]
	return tostring(size):gsub("LL$", "") .. ":" .. tostring(mtime):gsub("LL$", "")
end

-- Replace `path` with `text` through a unique temporary file and a rename,
-- creating parent directories as needed. Returns true on success; a failure
-- leaves no temporary file behind.
function M.write_atomic(path, text)
	local prefix = path:sub(1, 1) == "/" and "" or "."
	local dir = path:match("^(.*)/[^/]*$")
	if dir then
		for part in dir:gmatch("[^/]+") do
			prefix = prefix .. "/" .. part
			ffi.C.mkdir(prefix, 493) -- 0755; an existing directory is fine
		end
	end
	local temporary = path .. ".new." .. ffi.C.getpid()
	local file = io.open(temporary, "wb")
	if not file then return false end
	local wrote = file:write(text)
	local closed = file:close()
	if wrote and closed and ffi.C.rename(temporary, path) == 0 then return true end
	ffi.C.unlink(temporary)
	return false
end

-- Entry names of a directory, excluding "." and "..", or nil if it cannot be
-- opened. Order is whatever the filesystem returns.
function M.list_dir(path)
	local dir = ffi.C.opendir(path)
	if dir == nil then return nil end
	local names = {}
	while true do
		local entry = ffi.C.readdir(dir)
		if entry == nil then break end
		local name = ffi.string(ffi.cast("const char *", entry) + layout.name_offset)
		if name ~= "." and name ~= ".." then names[#names + 1] = name end
	end
	ffi.C.closedir(dir)
	return names
end

-- Bash sorts glob matches with strcoll under the shell's LC_COLLATE. Select
-- the collation from the environment, as Bash does at startup, and return a
-- strict-weak-order comparator for table.sort.
function M.environment_collation()
	os.setlocale("", "collate")
	return function(a, b) return ffi.C.strcoll(a, b) < 0 end
end

return M

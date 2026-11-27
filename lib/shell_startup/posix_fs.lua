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
local LAYOUTS = {
	["Linux/x64"] = { mode_offset = 24, mode_type = "uint32_t *", name_offset = 19 },
	["Linux/arm64"] = { mode_offset = 16, mode_type = "uint32_t *", name_offset = 19 },
	["OSX/arm64"] = { mode_offset = 4, mode_type = "uint16_t *", name_offset = 21 },
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

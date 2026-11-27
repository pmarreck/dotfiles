-- Compiled terminfo entries, read without starting infocmp. The old Sixel
-- probe ran `infocmp -1 | grep -q sixel`. What that command prints that could
-- contain "sixel" is the names line (names and description) and the standard
-- string values, both stored verbatim in the compiled entry; plain infocmp
-- hides user-defined capabilities, so visible_text leaves those out.
local M = {}

-- Directories in the order ncurses searches them: TERMINFO, ~/.terminfo,
-- TERMINFO_DIRS (an empty element means the system defaults), then the
-- system defaults.
local DEFAULTS = {
	"/etc/terminfo", "/lib/terminfo", "/usr/share/terminfo", "/usr/lib/terminfo",
	"/run/current-system/sw/share/terminfo", "/usr/share/lib/terminfo",
}

function M.search_dirs(env)
	local dirs = {}
	local function add(dir) if dir and dir ~= "" then dirs[#dirs + 1] = dir end end
	local function add_defaults() for _, dir in ipairs(DEFAULTS) do add(dir) end end
	add(env("TERMINFO"))
	if env("HOME") and env("HOME") ~= "" then add(env("HOME") .. "/.terminfo") end
	local list = env("TERMINFO_DIRS")
	local defaulted = false
	if list and list ~= "" then
		for dir in (list .. ":"):gmatch("([^:]*):") do
			if dir == "" then add_defaults(); defaulted = true else add(dir) end
		end
	end
	if not defaulted then add_defaults() end
	return dirs
end

-- The compiled entry for `term`, or nil. Entries live under a first-letter
-- directory, or its hex code on case-insensitive file systems (macOS).
function M.entry(term, env, read)
	if not term or term == "" or term:find("/", 1, true) or term:find("^%.") then return nil end
	local first = term:sub(1, 1)
	local hex = string.format("%02x", first:byte())
	for _, dir in ipairs(M.search_dirs(env)) do
		local data = read(dir .. "/" .. first .. "/" .. term) or read(dir .. "/" .. hex .. "/" .. term)
		if data then return data end
	end
	return nil
end

local function u16(s, at)
	local low, high = s:byte(at, at + 1)
	return low + high * 256
end

-- The names section and standard string table of a compiled entry (legacy
-- 16-bit or extended 32-bit number format). Unknown formats are searched whole.
function M.visible_text(entry)
	if not entry or #entry < 12 then return entry or "" end
	local magic = u16(entry, 1)
	if magic ~= 0x11A and magic ~= 0x21E then return entry end -- octal 0432, 01036
	local number_size = magic == 0x21E and 4 or 2
	local names_size, booleans, numbers, strings, table_size =
		u16(entry, 3), u16(entry, 5), u16(entry, 7), u16(entry, 9), u16(entry, 11)
	local names = entry:sub(13, 12 + names_size)
	local offset = 12 + names_size + booleans -- bytes before the numbers
	if offset % 2 == 1 then offset = offset + 1 end -- numbers start on an even byte
	offset = offset + numbers * number_size + strings * 2
	return names .. "\n" .. entry:sub(offset + 1, offset + table_size)
end

return M

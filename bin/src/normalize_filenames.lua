-- normalize_filenames: pure planning core for the normalize-filenames CLI. Given
-- every path found under the roots, decide which names to rewrite into Unicode
-- NFC (composed) form, which would collide with an existing or already-planned
-- sibling, and which are not valid UTF-8. No I/O happens here.

local nfc = require("unicode_nfc")

local M = {}

local function split(path)
	local parent, name = path:match("^(.*)/([^/]*)$")
	if not parent then return ".", path end
	return parent, name
end

local function depth(path)
	local _, n = path:gsub("/", "")
	return n
end

-- Plan renames. entries: list of paths (roots themselves excluded). Returns a
-- list of actions {kind = "rename"|"collision"|"invalid", path, new_path}
-- ordered deepest first, then by byte order, so a child is always renamed
-- while its parent still has its old name. Anything inside a git work tree
-- (a directory holding a .git file or directory) is left alone, root included,
-- because git tracks those names itself.
function M.plan(entries)
	local repo_roots, siblings = {}, {}
	for _, path in ipairs(entries) do
		local parent, name = split(path)
		if name == ".git" then repo_roots[parent] = true end
		local set = siblings[parent]
		if not set then
			set = {}
			siblings[parent] = set
		end
		set[name] = true
	end

	local function inside_repo(path)
		local p = path
		while p do
			if repo_roots[p] then return true end
			p = p:match("^(.*)/[^/]*$")
		end
		return false
	end

	local candidates = {}
	for _, path in ipairs(entries) do
		if not inside_repo(path) then
			local parent, name = split(path)
			local normalized = nfc.normalize(name)
			if not normalized then
				candidates[#candidates + 1] = { kind = "invalid", path = path, depth = depth(path) }
			elseif normalized ~= name then
				candidates[#candidates + 1] = { kind = "rename", path = path, parent = parent,
					new_name = normalized, depth = depth(path) }
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.depth ~= b.depth then return a.depth > b.depth end
		return a.path < b.path
	end)

	local planned, actions = {}, {}
	for _, c in ipairs(candidates) do
		if c.kind == "invalid" then
			actions[#actions + 1] = { kind = "invalid", path = c.path }
		else
			local new_path = c.parent .. "/" .. c.new_name
			local taken = planned[c.parent]
			if not taken then
				taken = {}
				planned[c.parent] = taken
			end
			if siblings[c.parent][c.new_name] or taken[c.new_name] then
				actions[#actions + 1] = { kind = "collision", path = c.path, new_path = new_path }
			else
				taken[c.new_name] = true
				actions[#actions + 1] = { kind = "rename", path = c.path, new_path = new_path }
			end
		end
	end
	return actions
end

-- Length of the well-formed UTF-8 sequence starting at byte i, or nil.
local function sequence_length(s, i)
	local b = s:byte(i)
	local len, lo, hi = 1, 0x80, 0xBF
	if b < 0x80 then return 1
	elseif b >= 0xC2 and b <= 0xDF then len = 2
	elseif b == 0xE0 then len, lo = 3, 0xA0
	elseif b == 0xED then len, hi = 3, 0x9F
	elseif b >= 0xE1 and b <= 0xEF then len = 3
	elseif b == 0xF0 then len, lo = 4, 0x90
	elseif b == 0xF4 then len, hi = 4, 0x8F
	elseif b >= 0xF1 and b <= 0xF3 then len = 4
	else return nil end
	local c = s:byte(i + 1)
	if not c or c < lo or c > hi then return nil end
	for k = 2, len - 1 do
		c = s:byte(i + k)
		if not c or c < 0x80 or c > 0xBF then return nil end
	end
	return len
end

-- Printable form of a file name: valid UTF-8 passes through, while stray bytes
-- and control characters become \xHH, so output stays one line per name.
function M.escape_bytes(s)
	local out, i = {}, 1
	while i <= #s do
		local b = s:byte(i)
		local len = sequence_length(s, i)
		if len == 1 and b >= 0x20 and b ~= 0x7F then
			out[#out + 1] = string.char(b)
			i = i + 1
		elseif len and len > 1 then
			out[#out + 1] = s:sub(i, i + len - 1)
			i = i + len
		else
			out[#out + 1] = string.format("\\x%02X", b)
			i = i + 1
		end
	end
	return table.concat(out)
end

function M.format_progress(count)
	local digits = tostring(count)
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "normalize-filenames: scanned " .. grouped .. " entries"
end

return M

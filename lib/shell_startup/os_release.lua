-- Linux distribution facts from os-release text, reproducing exactly what the
-- bin/distro, bin/distro_pretty, and bin/distro_version commands print when
-- captured by Bash command substitution. Pure: the caller supplies the text.
--
-- Those commands run awk with "=" as the field separator:
--   distro          /^NAME=/          { gsub(/"/, "", $2); print $2 }
--   distro_pretty   /^PRETTY_NAME=/   { gsub(/"/, "", $2); print $2 }
--   distro_version  $1=="VERSION_ID"  { gsub(/(^["]|["]$)/, "", $2); print $2 }
-- so $2 ends at the next "=", every match prints a line, and command
-- substitution then drops NUL bytes and all trailing newlines.
local M = {}

-- awk records: split on "\n"; a final newline does not open an empty record.
local function records(text)
	local out, start = {}, 1
	while start <= #text do
		local stop = text:find("\n", start, true)
		if not stop then
			out[#out + 1] = text:sub(start)
			break
		end
		out[#out + 1] = text:sub(start, stop - 1)
		start = stop + 1
	end
	return out
end

-- awk -F= fields $1 and $2 of one record.
local function fields(record)
	local first = record:find("=", 1, true)
	if not first then return record, "" end
	local second = record:find("=", first + 1, true)
	return record:sub(1, first - 1), record:sub(first + 1, second and second - 1 or nil)
end

local function captured(lines)
	local output = table.concat(lines, "\n")
	if #lines > 0 then output = output .. "\n" end
	return (output:gsub("%z", ""):gsub("\n+$", ""))
end

function M.facts(text)
	local names, pretty, versions = {}, {}, {}
	for _, record in ipairs(records(text)) do
		local first, second = fields(record)
		if record:sub(1, 5) == "NAME=" then names[#names + 1] = (second:gsub('"', "")) end
		if record:sub(1, 12) == "PRETTY_NAME=" then pretty[#pretty + 1] = (second:gsub('"', "")) end
		if first == "VERSION_ID" then
			local version = second:gsub('^"', "")
			versions[#versions + 1] = (version:gsub('"$', ""))
		end
	end
	return {
		DISTRO = captured(names),
		DISTRO_PRETTY = captured(pretty),
		DISTRO_VERSION = captured(versions),
	}
end

return M

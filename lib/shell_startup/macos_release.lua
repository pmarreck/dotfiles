-- macOS distribution facts without starting a process. .bashrc used to run
-- `sw_vers -productVersion` twice (once through bin/distro_version) and the
-- bin/mac_os_version_number_to_name script. sw_vers reads ProductVersion from
-- /System/Library/CoreServices/SystemVersion.plist; the marketing names come
-- from that script's own `case` table, parsed here so it stays the one list.
local M = {}

-- ProductVersion from the XML property list, or nil.
function M.product_version(plist)
	local version = (plist or ""):match("<key>ProductVersion</key>%s*<string>([^<]*)</string>")
	if version == nil or version == "" then return nil end
	return version
end

-- The script's `case $version in` arms as { lua pattern, name } in order. The
-- arms are globs of digits, dots, and `*`; each matches the whole version, and
-- the first match wins, as in a shell `case`.
function M.name_table(script)
	local block = (script or ""):match("\n%s*case %$version in\n(.-)\n%s*esac")
	local arms = {}
	for glob, name in (block or ""):gmatch("\n?%s*([%d%.%*]+)%)%s*distribution=\"([^\"]*)\"") do
		local pattern = "^" .. glob:gsub("%.", "%%."):gsub("%*", ".*") .. "$"
		arms[#arms + 1] = { pattern, name }
	end
	return arms
end

-- What the script prints for `version`: "VERSION (NAME)", or nil when no arm
-- matches (the script's last arm is a catch-all).
function M.version_name(version, arms)
	for _, arm in ipairs(arms) do
		if version:match(arm[1]) then return version .. " (" .. arm[2] .. ")" end
	end
	return nil
end

-- DISTRO, DISTRO_PRETTY, DISTRO_VERSION as .bashrc computed them, or nil when
-- either input is unusable, so .bashrc runs the commands as before.
function M.facts(plist, script)
	local version = M.product_version(plist)
	local pretty = version and M.version_name(version, M.name_table(script))
	if not pretty then return nil end
	return { DISTRO = "macOS", DISTRO_PRETTY = "macOS " .. pretty, DISTRO_VERSION = version }
end

return M

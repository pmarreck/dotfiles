local M = { README_HEADER_LINES = 40 }

local function root_name(name)
	return type(name) == "string" and not name:find("/", 1, true)
end

local function readme_name(name)
	return root_name(name) and name:lower() == "readme.md"
end

local function license_name(name)
	if not root_name(name) then return false end
	local lower = name:lower()
	return lower == "license"
		or lower == "license.md"
		or lower == "license.txt"
		or lower == "licence"
		or lower == "licence.md"
		or lower == "licence.txt"
		or lower == "copying"
		or lower == "copying.md"
		or lower == "copying.txt"
end

function M.is_profile_document(name)
	return readme_name(name) or license_name(name)
end

local function preferred_file(entries, predicate, canonical)
	local matches = {}
	for _, entry in ipairs(entries or {}) do
		if type(entry) == "table" and predicate(entry.name) then
			matches[#matches + 1] = entry
		end
	end
	table.sort(matches, function(left, right)
		if left.name == canonical then return true end
		if right.name == canonical then return false end
		return left.name < right.name
	end)
	return matches[1]
end

local function percent_decode(value)
	return (value:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function badge_line(repo_name, contents)
	local expected = "/badges/" .. repo_name:lower() .. ".json"
	local line_number = 0
	for line in ((contents or "") .. "\n"):gmatch("(.-)\n") do
		line_number = line_number + 1
		if line_number > M.README_HEADER_LINES then break end
		for alt, image_url in line:gmatch("!%[([^%]]*)%]%(([^%)]*)%)") do
			local lower_alt = alt:lower()
			local lower_url = percent_decode(image_url):lower()
			if lower_alt:find("mechatron", 1, true)
				and lower_url:find("img.shields.io/endpoint?", 1, true)
				and lower_url:find(expected, 1, true) then
				return line_number
			end
		end
	end
	return nil
end

--- Classify bounded root-file facts and the canonical Mechatron badge form.
--- The caller supplies file bytes, keeping this set classifier free of I/O.
function M.inspect_root(repo_name, entries)
	local readme = preferred_file(entries, readme_name, "README.md")
	local license = preferred_file(entries, license_name, "LICENSE")
	local line = readme and badge_line(repo_name, readme.contents) or nil
	return {
		status = "known",
		readme = {
			present = readme ~= nil,
			filename = readme and readme.name or "missing",
		},
		license = {
			present = license ~= nil,
			filename = license and license.name or "missing",
			type = "unknown",
			type_source = "unavailable",
		},
		mechatron_badge = {
			present = line ~= nil,
			line = line or 0,
			header_line_limit = M.README_HEADER_LINES,
		},
		primary_language = {
			name = "unknown",
			source = "unavailable",
		},
	}
end

local NON_SOURCE_TOKEI_KEYS = {
	["Total"] = true,
	["JSON"] = true,
	["Markdown"] = true,
	["Plain Text"] = true,
	["TOML"] = true,
	["YAML"] = true,
}

local function tokei_primary_language(tokei)
	local best_name, best_code
	for name, statistics in pairs(tokei or {}) do
		local code = type(statistics) == "table" and tonumber(statistics.code) or nil
		if not NON_SOURCE_TOKEI_KEYS[name] and code
			and (not best_code or code > best_code or (code == best_code and name < best_name)) then
			best_name, best_code = name, code
		end
	end
	return best_name
end

--- Add cached mechanical provider facts without weakening local document facts.
function M.enrich(local_profile, github, tokei)
	local result = {
		status = local_profile.status,
		readme = local_profile.readme,
		license = {
			present = local_profile.license.present,
			filename = local_profile.license.filename,
			type = "unknown",
			type_source = "unavailable",
		},
		mechatron_badge = local_profile.mechatron_badge,
		primary_language = { name = "unknown", source = "unavailable" },
	}
	local license = type(github) == "table" and github.licenseInfo or nil
	if type(license) == "table" then
		local identifier = license.spdxId or license.key or license.name
		if type(identifier) == "string" and identifier ~= "" then
			result.license.type = identifier
			result.license.type_source = "github"
		end
	end
	local language = type(github) == "table" and github.primaryLanguage or nil
	if type(language) == "table" and type(language.name) == "string"
		and language.name ~= "" then
		result.primary_language = { name = language.name, source = "github" }
	else
		local fallback = tokei_primary_language(tokei)
		if fallback then
			result.primary_language = { name = fallback, source = "tokei" }
		end
	end
	return result
end

return M

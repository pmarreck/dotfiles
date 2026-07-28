local M = {}

function M.github_slug(remote_url)
	if not remote_url then return nil end
	local slug = remote_url:match("^git@github%.com:([^/]+/[^/]+)%.git$")
		or remote_url:match("^git@github%.com:([^/]+/[^/]+)$")
		or remote_url:match("^https://github%.com/([^/]+/[^/]+)%.git$")
		or remote_url:match("^https://github%.com/([^/]+/[^/]+)$")
	if not slug then return nil end
	return slug:gsub("%.git$", "")
end

--- Classify Cargo manifest dependency tables as a set of direct package names,
--- including target-specific and dependency-specific TOML table forms.
function M.cargo_direct_dependencies(contents)
	local dependencies = {}
	local in_dependencies = false
	for line in contents:gmatch("[^\n]+") do
		local section = line:match("^%s*%[([^]]+)%]")
		if section then
			in_dependencies = section == "dependencies"
				or section == "dev-dependencies"
				or section == "build-dependencies"
				or section:match("%.dependencies$") ~= nil
			local table_dependency = section:match("^dependencies%.(.+)$")
				or section:match("^dev%-dependencies%.(.+)$")
				or section:match("^build%-dependencies%.(.+)$")
				or section:match("%.dependencies%.([^%.]+)$")
			if table_dependency then
				dependencies[table_dependency:gsub('^"(.*)"$', "%1")] = true
				in_dependencies = false
			end
		elseif in_dependencies then
			local name, value = line:match("^%s*[\"']?([%w_.-]+)[\"']?%s*=%s*(.-)%s*$")
			if name and not name:match("^#") then
				dependencies[value:match("package%s*=%s*[\"']([^\"']+)")
					or name] = true
			end
		end
	end
	return dependencies
end

function M.zig_github_pin(url)
	local owner, repository = url:match("github%.com/([^/]+)/([^/?#]+)")
	if repository then repository = repository:gsub("%.git$", "") end
	local pinned_sha = url:match("#([0-9a-fA-F][0-9a-fA-F]+)$")
		or url:match("/archive/([0-9a-fA-F]+)%.tar%.gz$")
		or url:match("/archive/([0-9a-fA-F]+)%.zip$")
	return owner, repository, pinned_sha
end

function M.strip_yaml_scalar(value)
	return value:gsub("^%s+", ""):gsub("%s+$", "")
		:gsub("^['\"]", ""):gsub("['\"]$", "")
end

return M

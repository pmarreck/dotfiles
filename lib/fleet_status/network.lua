local cjson = require("cjson")

--- Compose slow-tier collection around injected runtime, state, parser, and
--- provider ports; the facade owns construction and therefore dependency flow.
local function new(runtime, state, lock_parsers, providers, scheduler, repository_profile)
local M = { NETWORK_CACHE_VERSION = 4 }
local run_command = runtime.run_command
local run_git = runtime.run_git
local shell_quote = runtime.shell_quote
local trim = runtime.trim
local getenv = runtime.getenv
local current_time = runtime.now_epoch
local read_file = runtime.read_file
local remove_path = runtime.remove_path
local write_file = runtime.write_file
M.encode_json = state.encode_json
M.load_json_file = state.load_json_file
M.write_atomic = state.write_atomic

local function age_days(now_epoch, commit_epoch)
	commit_epoch = tonumber(commit_epoch)
	if not commit_epoch then return cjson.null end
	return math.max(0, math.floor((now_epoch - commit_epoch) / 86400))
end

local function decode_command_json(command)
	return providers.decode_json(command)
end

--- Configure a worker-local response cache so repeated provider queries across
--- ecosystems are deduplicated without coupling collectors to provider details.
function M.configure_provider_cache(options)
	providers.configure_cache(options)
end

local function github_slug(remote_url)
	return lock_parsers.github_slug(remote_url)
end

local function provider_command(environment_name, fallback, arguments)
	return providers.command(environment_name, fallback, arguments)
end

--- Discover a GitHub fork's actual parent through the API, then compare its
--- default branch without assuming that a local upstream remote exists.
local function collect_fork_drift(repo)
	local remote_url, has_remote = run_git(repo.path, "remote get-url origin")
	local slug = has_remote and github_slug(trim(remote_url)) or nil
	if not slug then
		return { status = "not_applicable", reason = "no_github_origin" }
	end
	local view = decode_command_json(provider_command(
		"FLEET_STATUS_GH",
		"gh",
		"repo view " .. shell_quote(slug)
			.. " --json nameWithOwner,parent,defaultBranchRef,isFork,pushedAt"
	))
	if type(view) ~= "table" or type(view.isFork) ~= "boolean" then
		return { status = "unknown", reason = "malformed_provider_response" }
	end
	local repository_pushed_at = type(view.pushedAt) == "string"
		and view.pushedAt or cjson.null
	if not view.isFork then
		return {
			status = "not_fork",
			repository = slug,
			repository_pushed_at = repository_pushed_at,
		}
	end
	if type(view.parent) ~= "table" then
		return { status = "unknown", reason = "malformed_provider_response" }
	end

	local parent = view.parent.nameWithOwner
		or (view.parent.owner and view.parent.owner.login
			and view.parent.name
			and (view.parent.owner.login .. "/" .. view.parent.name))
	local fork_branch = view.defaultBranchRef and view.defaultBranchRef.name
	local parent_view = parent and decode_command_json(provider_command(
		"FLEET_STATUS_GH",
		"gh",
		"repo view " .. shell_quote(parent)
			.. " --json nameWithOwner,defaultBranchRef,pushedAt"
	)) or nil
	local parent_branch = type(parent_view) == "table" and parent_view.defaultBranchRef
		and parent_view.defaultBranchRef.name
	local parent_pushed_at = type(parent_view) == "table"
		and type(parent_view.pushedAt) == "string"
		and parent_view.pushedAt or cjson.null
	if not parent or not fork_branch or not parent_branch then
		return { status = "unknown", reason = "missing_default_branch" }
	end
	local owner = slug:match("^([^/]+)/")
	local comparison = decode_command_json(provider_command(
		"FLEET_STATUS_GH",
		"gh",
		"api " .. shell_quote(
			"repos/" .. parent .. "/compare/" .. parent_branch
				.. "..." .. owner .. ":" .. fork_branch
		)
	))
	if type(comparison) ~= "table"
		or type(comparison.ahead_by) ~= "number"
		or type(comparison.behind_by) ~= "number" then
		return {
			status = "unknown",
			reason = "provider_unavailable",
			parent = parent,
			fork_default_branch = fork_branch,
			parent_default_branch = parent_branch,
		}
	end
	local ahead = comparison.ahead_by
	local behind = comparison.behind_by
	local common_commit_at = comparison.merge_base_commit
		and comparison.merge_base_commit.commit
		and (comparison.merge_base_commit.commit.committer
			and comparison.merge_base_commit.commit.committer.date
			or comparison.merge_base_commit.commit.author
			and comparison.merge_base_commit.commit.author.date)
	local relation = "even"
	if ahead > 0 and behind > 0 then
		relation = "diverged"
	elseif behind > 0 then
		relation = "behind"
	elseif ahead > 0 then
		relation = "ahead"
	end
	return {
		status = "known",
		repository = slug,
		repository_pushed_at = repository_pushed_at,
		parent = parent,
		parent_pushed_at = parent_pushed_at,
		fork_default_branch = fork_branch,
		parent_default_branch = parent_branch,
		ahead = ahead,
		behind = behind,
		last_common_commit_at = common_commit_at or cjson.null,
		last_common_commit_epoch = scheduler.parse_utc_timestamp(common_commit_at)
			or cjson.null,
		relation = relation,
	}
end

local function collect_github_pin(kind, name, owner, repository, ref, pinned_sha, pinned_epoch, now_epoch)
	local head = decode_command_json(provider_command(
		"FLEET_STATUS_GH",
		"gh",
		"api " .. shell_quote("repos/" .. owner .. "/" .. repository .. "/commits/" .. ref)
	))
	local record = {
		kind = kind,
		name = name,
		source = owner .. "/" .. repository,
		ref = ref,
		pinned_sha = pinned_sha,
		pinned_epoch = pinned_epoch,
	}
	if type(head) ~= "table" or type(head.sha) ~= "string" then
		record.status = "unknown"
		record.reason = "provider_unavailable"
		return record
	end
	record.head_sha = head.sha
	if head.sha == pinned_sha or (#pinned_sha < 40 and head.sha:sub(1, #pinned_sha) == pinned_sha) then
		record.status = "current"
		record.commits_stale = 0
		record.days_stale = 0
		return record
	end
	record.days_stale = pinned_epoch and age_days(now_epoch, pinned_epoch) or cjson.null
	local comparison = decode_command_json(provider_command(
		"FLEET_STATUS_GH",
		"gh",
		"api " .. shell_quote(
			"repos/" .. owner .. "/" .. repository .. "/compare/"
				.. pinned_sha .. "..." .. head.sha
		)
	))
	if type(comparison) ~= "table"
		or type(comparison.ahead_by) ~= "number"
		or type(comparison.behind_by) ~= "number" then
		record.status = "unknown"
		record.reason = "comparison_unavailable"
		return record
	end
	record.commits_stale = comparison.ahead_by
	record.status = comparison.behind_by > 0 and "diverged" or "stale"
	return record
end

local function collect_flake_pins(repo, now_epoch)
	local contents = read_file(repo.path .. "/flake.lock")
	if not contents then return {} end
	local decoded_ok, lock = pcall(cjson.decode, contents)
	if not decoded_ok or type(lock.nodes) ~= "table" then
		return {
			{ kind = "flake", name = "flake.lock", status = "unknown", reason = "invalid_lock" },
		}
	end
	local pins = {}
	for name, node in pairs(lock.nodes) do
		local locked = type(node) == "table" and node.locked or nil
		local original = type(node) == "table" and node.original or nil
		if type(locked) == "table" then
			local owner, repository
			if locked.type == "github" then
				owner, repository = locked.owner, locked.repo
			elseif locked.type == "git" and type(locked.url) == "string" then
				owner, repository = locked.url:match("github%.com/([^/]+)/([^/?#]+)")
				if repository then repository = repository:gsub("%.git$", "") end
			end
			if owner and repository and type(locked.rev) == "string" then
				pins[#pins + 1] = collect_github_pin(
					"flake",
					name,
					owner,
					repository,
					(type(original) == "table" and original.ref) or "HEAD",
					locked.rev,
					tonumber(locked.lastModified),
					now_epoch
				)
			else
				pins[#pins + 1] = {
					kind = "flake",
					name = name,
					source_type = locked.type or cjson.null,
					source = locked.url or cjson.null,
					status = "unknown",
					reason = "uncomparable_source",
				}
			end
		end
	end
	table.sort(pins, function(left, right) return left.name < right.name end)
	return pins
end

local function url_encode(value)
	return tostring(value):gsub("[^A-Za-z0-9._~-]", function(character)
		return string.format("%%%02X", character:byte())
	end)
end

local function collect_registry_pin(kind, name, locked_version, url, version_reader)
	local response = decode_command_json(provider_command(
		"FLEET_STATUS_CURL",
		"curl",
		"--fail --silent --show-error " .. shell_quote(url)
	))
	local record = {
		kind = kind,
		name = name,
		locked_version = locked_version,
	}
	local upstream = response and version_reader(response) or nil
	if not upstream then
		record.status = "unknown"
		record.reason = "provider_unavailable"
		return record
	end
	record.upstream_version = upstream
	record.status = upstream == locked_version and "current" or "stale"
	return record
end

local function collect_zig_pins(repo, now_epoch)
	local contents = read_file(repo.path .. "/build.zig.zon")
	if not contents then return {} end
	local pins = {}
	for position, url in contents:gmatch("()%.url%s*=%s*\"([^\"]+)\"") do
		local before = contents:sub(1, position - 1)
		local name = before:match('%.@"([^"]+)"%s*=%s*%.%s*{%s*$')
			or before:match("%.([%w_-]+)%s*=%s*%.%s*{%s*$")
			or url
		local owner, repository, pinned_sha = lock_parsers.zig_github_pin(url)
		if owner and repository and pinned_sha and #pinned_sha >= 7 and #pinned_sha <= 40 then
			local ref = url:match("[?&]ref=([^&#]+)") or "HEAD"
			local pin = collect_github_pin(
				"zig",
				name,
				owner,
				repository,
				ref,
				pinned_sha,
				nil,
				now_epoch
			)
			pins[#pins + 1] = pin
		elseif owner and repository then
			pins[#pins + 1] = {
				kind = "zig",
				name = name,
				source = owner .. "/" .. repository,
				status = "unknown",
				reason = "immutable_or_unrecognized_pin",
			}
		else
			pins[#pins + 1] = {
				kind = "zig",
				name = name,
				source = url,
				status = "unknown",
				reason = "uncomparable_source",
			}
		end
	end
	return pins
end

local function cargo_direct_dependencies(contents)
	return lock_parsers.cargo_direct_dependencies(contents)
end

local function collect_cargo_pins(repo, now_epoch)
	local manifest = read_file(repo.path .. "/Cargo.toml")
	local lock = read_file(repo.path .. "/Cargo.lock")
	if not manifest or not lock then return {} end
	local direct = cargo_direct_dependencies(manifest)
	local pins = {}
	local cursor = 1
	while true do
		local start_at = lock:find("[[package]]", cursor, true)
		if not start_at then break end
		local next_at = lock:find("[[package]]", start_at + 11, true)
		local block = lock:sub(start_at + 11, (next_at or (#lock + 1)) - 1)
		local name = block:match("\n%s*name%s*=%s*\"([^\"]+)\"")
			or block:match("^%s*name%s*=%s*\"([^\"]+)\"")
		local version = block:match("\n%s*version%s*=%s*\"([^\"]+)\"")
		local source = block:match("\n%s*source%s*=%s*\"([^\"]+)\"")
		if name and version and direct[name] then
			local owner, repository, sha
			if source then
				owner, repository = source:match("github%.com/([^/]+)/([^/?#]+)")
				sha = source:match("#([0-9a-fA-F]+)$")
			end
			if repository then repository = repository:gsub("%.git$", "") end
			if owner and repository and sha and #sha == 40 then
				pins[#pins + 1] = collect_github_pin(
					"cargo",
					name,
					owner,
					repository,
					(source:match("[?&]branch=([^&#]+)") or "HEAD"),
					sha,
					nil,
					now_epoch
				)
			elseif source and source:match("^registry%+") then
				pins[#pins + 1] = collect_registry_pin(
					"cargo",
					name,
					version,
					"https://crates.io/api/v1/crates/" .. url_encode(name),
					function(response)
						return response.crate and response.crate.newest_version
					end
				)
			end
		end
		cursor = next_at or (#lock + 1)
	end
	return pins
end

local function npm_latest_pin(kind, name, version)
	return collect_registry_pin(
		kind,
		name,
		version,
		"https://registry.npmjs.org/" .. url_encode(name) .. "/latest",
		function(response) return response.version end
	)
end

local function collect_npm_pins(repo)
	local contents = read_file(repo.path .. "/package-lock.json")
	if not contents then return {} end
	local decoded_ok, lock = pcall(cjson.decode, contents)
	if not decoded_ok then
		return {
			{ kind = "npm", name = "package-lock.json", status = "unknown", reason = "invalid_lock" },
		}
	end
	if type(lock.packages) ~= "table" and type(lock.dependencies) == "table" then
		local pins = {}
		for name, package in pairs(lock.dependencies) do
			if type(package) == "table" and package.version then
				pins[#pins + 1] = npm_latest_pin("npm", name, package.version)
			end
		end
		return pins
	elseif type(lock.packages) ~= "table" then
		return {
			{ kind = "npm", name = "package-lock.json", status = "unknown", reason = "invalid_lock" },
		}
	end
	local direct = {}
	for path, package in pairs(lock.packages) do
		local installed_entry = path:sub(1, 13) == "node_modules/"
			or path:find("/node_modules/", 1, true) ~= nil
		if not installed_entry and type(package) == "table" then
			for _, field in ipairs({ "dependencies", "devDependencies", "optionalDependencies" }) do
				for name in pairs(package[field] or {}) do direct[name] = true end
			end
		end
	end
	local pins = {}
	for name in pairs(direct) do
		local installed = lock.packages["node_modules/" .. name]
		if not installed then
			local suffix = "/node_modules/" .. name
			for path, package in pairs(lock.packages) do
				if path:sub(-#suffix) == suffix then
					installed = package
					break
				end
			end
		end
		if installed and installed.version then
			pins[#pins + 1] = npm_latest_pin("npm", name, installed.version)
		else
			pins[#pins + 1] = {
				kind = "npm",
				name = name,
				status = "unknown",
				reason = "missing_locked_version",
			}
		end
	end
	return pins
end

local function strip_yaml_scalar(value)
	return lock_parsers.strip_yaml_scalar(value)
end

local function collect_pnpm_pins(repo)
	local contents = read_file(repo.path .. "/pnpm-lock.yaml")
	if not contents then return {} end
	local pins = {}
	local seen = {}
	local in_importers, in_dependencies, current_name = false, false, nil
	for line in contents:gmatch("[^\n]+") do
		if line:match("^importers:%s*$") then
			in_importers, in_dependencies, current_name = true, false, nil
		elseif in_importers and line:match("^[^ ]") then
			break
		elseif in_importers and line:match("^  [^ ]") then
			in_dependencies, current_name = false, nil
		elseif in_importers then
			local category = line:match("^    ([A-Za-z]+):%s*$")
			if category == "devDependencies" or category == "dependencies"
				or category == "optionalDependencies" then
				in_dependencies, current_name = true, nil
			elseif line:match("^    [^ ]") then
				in_dependencies, current_name = false, nil
			elseif in_dependencies then
				local quoted_name = line:match("^      ['\"]([^'\"]+)['\"]:%s*$")
				local plain_name = line:match("^      ([^'\" ][^:]*):%s*$")
				if quoted_name or plain_name then
					current_name = quoted_name or plain_name
				else
					local version = line:match("^        version:%s*(.-)%s*$")
					if current_name and version then
						version = strip_yaml_scalar(version):gsub("%(.*$", "")
						local key = current_name .. "\0" .. version
						if not seen[key] then
							seen[key] = true
							pins[#pins + 1] = npm_latest_pin("pnpm", current_name, version)
						end
						current_name = nil
					end
				end
			end
		end
	end
	return pins
end

local function collect_pin_drift(repo, now_epoch)
	local pins = collect_flake_pins(repo, now_epoch)
	for _, collector in ipairs({
		collect_zig_pins,
		collect_cargo_pins,
		collect_npm_pins,
		collect_pnpm_pins,
	}) do
		for _, pin in ipairs(collector(repo, now_epoch)) do pins[#pins + 1] = pin end
	end
	table.sort(pins, function(left, right)
		if left.kind == right.kind then return left.name < right.name end
		return left.kind < right.kind
	end)
	return pins
end

local function collect_repository_profile(repo)
	local remote_url, has_remote = run_git(repo.path, "remote get-url origin")
	local slug = has_remote and github_slug(trim(remote_url)) or nil
	local github = slug and decode_command_json(provider_command(
		"FLEET_STATUS_GH",
		"gh",
		"repo view " .. shell_quote(slug) .. " --json licenseInfo,primaryLanguage"
	)) or nil
	local has_github_language = type(github) == "table"
		and type(github.primaryLanguage) == "table"
		and type(github.primaryLanguage.name) == "string"
	local tokei = not has_github_language and decode_command_json(provider_command(
		"FLEET_STATUS_TOKEI",
		"tokei",
		"--output json " .. shell_quote(repo.path)
	)) or nil
	local local_profile = type(repo.repository_profile) == "table"
		and repo.repository_profile or repository_profile.inspect_root(repo.name, {})
	return repository_profile.enrich(local_profile, github, tokei)
end

local function mechatron_configuration(badge_present, targets_present)
	if badge_present and targets_present then return "complete" end
	if badge_present then return "badge_only" end
	if targets_present then return "targets_only" end
	return "absent"
end

local function mechatron_base(repo, manifest)
	local badge = repo.repository_profile
		and repo.repository_profile.mechatron_badge
		and repo.repository_profile.mechatron_badge.present == true
	local targets = manifest ~= nil
	local configuration = mechatron_configuration(badge, targets)
	return {
		status = "known",
		configured = configuration == "complete",
		configuration = configuration,
		badge_present = badge,
		targets_manifest_present = targets,
		missing_targets_manifest = not targets,
		queried_commit = repo.head_sha,
		head_status = configuration == "absent" and "not_configured" or "unknown",
		last_result = cjson.null,
	}
end

local function collect_mechatron(repo)
	local manifest = read_file(repo.path .. "/.mechatron-prime/targets")
	local record = mechatron_base(repo, manifest)
	if record.configuration == "absent" then return record end
	if type(repo.head_sha) ~= "string" or #repo.head_sha < 7 then
		record.status = "unknown"
		record.reason = "missing_head"
		return record
	end
	local result = decode_command_json(provider_command(
		"FLEET_STATUS_MECHATRON_CI",
		"mechatron-ci",
		"log --project " .. shell_quote(repo.name)
			.. " --commit " .. shell_quote(repo.head_sha) .. " --json --limit 1"
	))
	if type(result) ~= "table" or type(result.results) ~= "table" then
		record.status = "unknown"
		record.reason = "malformed_or_unavailable_provider"
		return record
	end
	if type(result.results[1]) == "table" then
		record.last_result = result.results[1]
		record.head_status = result.results[1].status == "success" and "passing" or "failing"
		return record
	end
	local queue = decode_command_json(provider_command(
		"FLEET_STATUS_MECHATRON_CI",
		"mechatron-ci",
		"queue --project " .. shell_quote(repo.name)
			.. " --commit " .. shell_quote(repo.head_sha) .. " --json"
	))
	if type(queue) ~= "table" or type(queue.worker) ~= "table"
		or type(queue.claimed) ~= "table" or type(queue.waiting) ~= "table" then
		record.status = "unknown"
		record.reason = "malformed_or_unavailable_queue"
		return record
	end
	if type(queue.worker.current) == "table" or #queue.claimed > 0 then
		record.head_status = "building"
	elseif #queue.waiting > 0 then
		record.head_status = "queued"
	else
		record.head_status = "not_run"
	end
	return record
end

--- Collect slow tiers as independently nullable fields; every external failure
--- is converted to healthy JSON data rather than escaping as process failure.
function M.collect_network_repo(repo, now_epoch)
	local function isolated(collector, fallback)
		local ok, result = pcall(collector, repo, now_epoch)
		if ok and type(result) == "table" then return result end
		return fallback
	end
	return {
		repository_profile = isolated(
			collect_repository_profile,
			repo.repository_profile or repository_profile.inspect_root(repo.name, {})
		),
		fork_drift = isolated(
			collect_fork_drift,
			{ status = "unknown", reason = "collector_failure" }
		),
		pin_drift = isolated(
			collect_pin_drift,
			{ { kind = "collection", name = repo.name, status = "unknown", reason = "collector_failure" } }
		),
		mechatron = isolated(
			collect_mechatron,
			{
				status = "unknown",
				reason = "collector_failure",
				missing_targets_manifest = cjson.null,
			}
		),
	}
end

local function probe_github_repository(repository)
	local view = decode_command_json(provider_command(
		"FLEET_STATUS_GH",
		"gh",
		"repo view " .. shell_quote(repository)
			.. " --json nameWithOwner,pushedAt"
	))
	local pushed_at = type(view) == "table" and view.pushedAt or nil
	if type(pushed_at) ~= "string" then return nil, "provider_unavailable" end
	return pushed_at
end

--- Probe a repository's origin and optional fork parent; unchanged remote
--- timestamps justify carrying the complete cached observation another week.
function M.probe_network_repo(_repo, cached, now_epoch)
	local fork = type(cached) == "table" and cached.fork_drift or nil
	if type(fork) ~= "table" then return nil, nil, "missing_remote" end
	local repository = fork.repository
	local parent = fork.parent
	if type(repository) ~= "string" and type(parent) ~= "string" then
		return nil, nil, "missing_remote"
	end
	if type(repository) == "string" then
		local pushed_at, err = probe_github_repository(repository)
		if not pushed_at then return nil, nil, err end
		if pushed_at ~= fork.repository_pushed_at then return nil, true, nil end
	end
	if type(parent) == "string" then
		local pushed_at, err = probe_github_repository(parent)
		if not pushed_at then return nil, nil, err end
		if pushed_at ~= fork.parent_pushed_at then return nil, true, nil end
	end
	cached.upstream_probed_at_epoch = now_epoch
	return cached, false, nil
end

local function cache_key(repo)
	local hash = 5381
	for index = 1, #repo.path do
		hash = (hash * 33 + repo.path:byte(index)) % 4294967296
	end
	local safe_name = repo.name:gsub("[^A-Za-z0-9._-]", "_")
	return safe_name .. "-" .. string.format("%08x", hash)
end

local NETWORK_INPUT_FILES = {
	"flake.lock",
	"build.zig.zon",
	"Cargo.toml",
	"Cargo.lock",
	"package-lock.json",
	"pnpm-lock.yaml",
	".mechatron-prime/targets",
}

--- Fingerprint every local input that can change slow-tier meaning so a warm
--- cache cannot conceal edited pins, branch identity, remotes, or CI targets.
local function network_fingerprint(repo)
	local parts = {
		repo.path,
		tostring(repo.head_sha),
		tostring(repo.branch),
		M.encode_json(repo.repository_profile or {}),
	}
	local origin, has_origin = run_git(repo.path, "remote get-url origin")
	parts[#parts + 1] = has_origin and trim(origin) or "<no-origin>"
	for _, relative in ipairs(NETWORK_INPUT_FILES) do
		parts[#parts + 1] = relative
		parts[#parts + 1] = read_file(repo.path .. "/" .. relative) or "<missing>"
	end
	local value = table.concat(parts, "\0")
	local hash = 5381
	for index = 1, #value do
		hash = (hash * 33 + value:byte(index)) % 4294967296
	end
	return string.format("%08x", hash)
end

local function network_unknown(repo)
	return {
		repo_path = repo.path,
		repository_profile = repo.repository_profile
			or repository_profile.inspect_root(repo.name, {}),
		fork_drift = { status = "unknown", reason = "worker_unavailable" },
		pin_drift = {
			{ kind = "collection", name = repo.name, status = "unknown", reason = "worker_unavailable" },
		},
		mechatron = {
			status = "unknown",
			reason = "worker_unavailable",
			missing_targets_manifest = cjson.null,
		},
	}
end

local function valid_network_payload(payload)
	if type(payload) ~= "table"
		or type(payload.repository_profile) ~= "table"
		or type(payload.repository_profile.status) ~= "string"
		or type(payload.fork_drift) ~= "table"
		or type(payload.fork_drift.status) ~= "string"
		or type(payload.pin_drift) ~= "table"
		or type(payload.mechatron) ~= "table"
		or type(payload.mechatron.status) ~= "string"
		or not tonumber(payload.cached_at_epoch)
		or not tonumber(payload.upstream_probed_at_epoch) then
		return false
	end
	for _, pin in ipairs(payload.pin_drift) do
		if type(pin) ~= "table" or type(pin.status) ~= "string" then return false end
	end
	return true
end

local function tier_health(repos, tier)
	local known, unknown = 0, 0
	for _, repo in ipairs(repos) do
		if tier == 3 then
			if repo.fork_drift.status == "unknown" then unknown = unknown + 1 else known = known + 1 end
		elseif tier == 4 then
			local repo_unknown, repo_known = false, #repo.pin_drift == 0
			for _, pin in ipairs(repo.pin_drift) do
				if pin.status == "unknown" then repo_unknown = true else repo_known = true end
			end
			if repo_unknown then unknown = unknown + 1 end
			if repo_known then known = known + 1 end
		elseif tier == 5 then
			if repo.mechatron.status == "unknown" then unknown = unknown + 1 else known = known + 1 end
		end
	end
	if unknown == 0 then return "known" end
	if known == 0 then return "unknown" end
	return "partial"
end

--- Run one cacheable job per repository through portable xargs -P, bounding
--- provider concurrency identically on macOS and Linux.
function M.enrich_network(snapshot, options)
	options = options or {}
	local state_dir = assert(options.state_dir)
	local jobs = math.max(1, math.floor(tonumber(options.jobs) or 4))
	local ttl_seconds = math.max(0, tonumber(options.ttl_seconds) or 86400)
	local save_cache = options.save_cache ~= false
	local now_epoch = tonumber(snapshot.collected_at_epoch) or current_time()
	local cache_dir = state_dir .. "/network-cache"
	local provider_cache_dir = cache_dir .. "/provider"
	if save_cache then
		local _, made_cache = run_command("mkdir -p " .. shell_quote(provider_cache_dir))
		if not made_cache then return nil, "cannot create network cache: " .. cache_dir end
	end

	local job_template = save_cache and (cache_dir .. "/jobs.XXXXXX")
		or ((getenv("TMPDIR") or "/tmp") .. "/fleet-status-network.XXXXXX")
	local job_dir_output, made_jobs = run_command(
		"mktemp -d " .. shell_quote(job_template)
	)
	local job_dir = trim(job_dir_output)
	if not made_jobs or job_dir == "" then return nil, "cannot create network job directory" end
	local input_path = job_dir .. "/inputs"
	local input_paths = {}
	local pending = {}
	local payloads = {}
	for index, repo in ipairs(snapshot.repos) do
		local cache_path = cache_dir .. "/" .. cache_key(repo) .. ".json"
		local cached = M.load_json_file(cache_path)
		local fingerprint = network_fingerprint(repo)
		local cache_usable = ttl_seconds > 0 and cached
			and valid_network_payload(cached)
			and cached.network_cache_version == M.NETWORK_CACHE_VERSION
			and cached.repo_path == repo.path
		local action = cache_usable
			and scheduler.network_action(now_epoch, repo, cached, fingerprint)
			or "full"
		if action == "carry" then
			payloads[index] = cached
		else
			local job_path = job_dir .. "/" .. tostring(index) .. ".json"
			local output_path = save_cache and cache_path
				or (job_dir .. "/" .. tostring(index) .. ".result.json")
			local ok, err = M.write_atomic(job_path, M.encode_json({
				repo = repo,
				mode = action,
				cached = action == "probe" and cached or nil,
				now_epoch = now_epoch,
				output = output_path,
				network_fingerprint = fingerprint,
				provider_cache = {
					directory = provider_cache_dir,
					ttl_seconds = ttl_seconds,
					now_epoch = now_epoch,
					save = save_cache,
				},
			}) .. "\n")
			if not ok then return nil, err end
			input_paths[#input_paths + 1] = job_path
			pending[#pending + 1] = {
				index = index,
				job = job_path,
				output = output_path,
				transient_output = not save_cache,
				mode = action,
				fallback = cache_usable and cached or nil,
				network_fingerprint = fingerprint,
			}
		end
	end
	local wrote_inputs, input_err = write_file(
		input_path,
		#input_paths > 0 and (table.concat(input_paths, "\0") .. "\0") or ""
	)
	if not wrote_inputs then return nil, input_err end

	if #pending > 0 then
		local worker = options.worker or ((options.bin_dir or "") .. "/fleet-status-network-worker")
		local xargs = getenv("FLEET_STATUS_XARGS") or "xargs"
		run_command(
			shell_quote(xargs) .. " -0 -n 1 -P " .. tostring(jobs) .. " "
				.. shell_quote(worker) .. " < " .. shell_quote(input_path)
		)
		for _, item in ipairs(pending) do
			local payload = M.load_json_file(item.output)
			local expected_time = item.mode == "probe"
				and tonumber(payload and payload.upstream_probed_at_epoch)
				or tonumber(payload and payload.cached_at_epoch)
			if not valid_network_payload(payload)
				or payload.network_cache_version ~= M.NETWORK_CACHE_VERSION
				or payload.repo_path ~= snapshot.repos[item.index].path
				or payload.network_fingerprint ~= item.network_fingerprint
				or expected_time ~= now_epoch then
				payload = item.fallback or network_unknown(snapshot.repos[item.index])
			end
			payloads[item.index] = payload
			remove_path(item.job)
			if item.transient_output then remove_path(item.output) end
		end
	end
	remove_path(input_path)
	remove_path(job_dir)

	for index, repo in ipairs(snapshot.repos) do
		local payload = payloads[index] or network_unknown(repo)
		repo.fork_drift = payload.fork_drift
		repo.pin_drift = payload.pin_drift
		repo.mechatron = payload.mechatron
		repo.repository_profile = payload.repository_profile
		repo.network_checked_at_epoch = tonumber(payload.cached_at_epoch) or cjson.null
		repo.upstream_probed_at_epoch = tonumber(payload.upstream_probed_at_epoch) or cjson.null
	end
	snapshot.tiers["3"] = tier_health(snapshot.repos, 3)
	snapshot.tiers["4"] = tier_health(snapshot.repos, 4)
	snapshot.tiers["5"] = tier_health(snapshot.repos, 5)
	return snapshot
end

return M
end

return { new = new }

local cjson = require("cjson")

--- Compose slow-tier collection around injected runtime, state, parser, and
--- provider ports; the facade owns construction and therefore dependency flow.
local function new(runtime, state, lock_parsers, providers)
local M = { NETWORK_CACHE_VERSION = 2 }
local read_file = runtime.read_file
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
			.. " --json nameWithOwner,parent,defaultBranchRef,isFork"
	))
	if type(view) ~= "table" or type(view.isFork) ~= "boolean" then
		return { status = "unknown", reason = "malformed_provider_response" }
	end
	if not view.isFork then
		return { status = "not_fork", repository = slug }
	end
	if type(view.parent) ~= "table" then
		return { status = "unknown", reason = "malformed_provider_response" }
	end

	local parent = view.parent.nameWithOwner
		or (view.parent.owner and view.parent.owner.login
			and view.parent.name
			and (view.parent.owner.login .. "/" .. view.parent.name))
	local fork_branch = view.defaultBranchRef and view.defaultBranchRef.name
	local parent_branch = view.parent.defaultBranchRef and view.parent.defaultBranchRef.name
	if parent and not parent_branch then
		local parent_view = decode_command_json(provider_command(
			"FLEET_STATUS_GH",
			"gh",
			"repo view " .. shell_quote(parent)
				.. " --json nameWithOwner,defaultBranchRef"
		))
		parent_branch = type(parent_view) == "table" and parent_view.defaultBranchRef
			and parent_view.defaultBranchRef.name
	end
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
		parent = parent,
		fork_default_branch = fork_branch,
		parent_default_branch = parent_branch,
		ahead = ahead,
		behind = behind,
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

local function collect_mechatron(repo)
	local manifest = read_file(repo.path .. "/.mechatron-prime/targets")
	local missing_manifest = manifest == nil
	local result = decode_command_json(provider_command(
		"FLEET_STATUS_MECHATRON_CI",
		"mechatron-ci",
		"log --project " .. shell_quote(repo.name) .. " --json --limit 1"
	))
	if type(result) ~= "table" or type(result.results) ~= "table" then
		return {
			status = "unknown",
			reason = "malformed_or_unavailable_provider",
			missing_targets_manifest = missing_manifest,
		}
	end
	return {
		status = "known",
		missing_targets_manifest = missing_manifest,
		last_result = result.results and result.results[1] or cjson.null,
	}
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
		or type(payload.fork_drift) ~= "table"
		or type(payload.fork_drift.status) ~= "string"
		or type(payload.pin_drift) ~= "table"
		or type(payload.mechatron) ~= "table"
		or type(payload.mechatron.status) ~= "string" then
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
		if ttl_seconds > 0 and cached
			and valid_network_payload(cached)
			and cached.network_cache_version == M.NETWORK_CACHE_VERSION
			and cached.repo_path == repo.path
			and cached.network_fingerprint == fingerprint
			and tonumber(cached.cached_at_epoch)
			and now_epoch - tonumber(cached.cached_at_epoch) <= ttl_seconds then
			payloads[index] = cached
		else
			local job_path = job_dir .. "/" .. tostring(index) .. ".json"
			local output_path = save_cache and cache_path
				or (job_dir .. "/" .. tostring(index) .. ".result.json")
			local ok, err = M.write_atomic(job_path, M.encode_json({
				repo = repo,
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
			if not valid_network_payload(payload)
				or payload.network_cache_version ~= M.NETWORK_CACHE_VERSION
				or payload.repo_path ~= snapshot.repos[item.index].path
				or payload.network_fingerprint ~= item.network_fingerprint
				or tonumber(payload.cached_at_epoch) ~= now_epoch then
				payload = network_unknown(snapshot.repos[item.index])
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
	end
	snapshot.tiers["3"] = tier_health(snapshot.repos, 3)
	snapshot.tiers["4"] = tier_health(snapshot.repos, 4)
	snapshot.tiers["5"] = tier_health(snapshot.repos, 5)
	return snapshot
end

return M
end

return { new = new }

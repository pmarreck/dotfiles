local M = {}
local cjson = require("cjson")
M.VERSION = "0.1.0"
M.NETWORK_CACHE_VERSION = 2
if cjson.encode_empty_table_as_object then
	cjson.encode_empty_table_as_object(false)
end

local CATEGORY_ORDER = {
	{ key = "unknown", label = "unknown" },
	{ key = "unpushed", label = "unpushed" },
	{ key = "orphaned", label = "orphaned" },
	{ key = "no_remote", label = "no-remote" },
	{ key = "modified", label = "modified" },
	{ key = "staged", label = "staged" },
	{ key = "untracked", label = "untracked" },
	{ key = "stashed", label = "stashed" },
}

local function repo_id(repo)
	return repo.path or repo.name
end

--- Project a repository record onto immediate-action risk scalars.
--- Numeric values preserve count changes for delta rendering.
local function risk_values(repo)
	local dirty = repo.dirty or {}
	local ahead = 0
	for _, branch in ipairs(repo.branches or {}) do
		ahead = ahead + (tonumber(branch.ahead) or 0)
	end
	return {
		unknown = (dirty.status == "unknown"
			or repo.orphaned_status == "unknown"
			or repo.branches_status == "unknown"
			or repo.remote_status == "unknown"
			or repo.stash_status == "unknown") and 1 or 0,
		unpushed = ahead,
		orphaned = #(repo.orphaned_commits or {}),
		no_remote = repo.no_remote == true and 1 or 0,
		modified = tonumber(dirty.modified) or 0,
		staged = tonumber(dirty.staged) or 0,
		untracked = tonumber(dirty.untracked) or 0,
		stashed = tonumber(repo.stash_count) or 0,
	}
end

local function sorted_names(entries)
	local names = {}
	for _, entry in ipairs(entries) do
		names[#names + 1] = entry.name
	end
	table.sort(names)
	return names
end

local function sanitize_text(value)
	value = tostring(value or "")
	value = value:gsub("[%c]", function(character)
		return string.format("\\x%02X", character:byte())
	end)
	return value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function render_names(entries, max_names)
	local names = sorted_names(entries)
	local shown = {}
	local limit = math.min(#names, max_names)
	for index = 1, limit do
		shown[#shown + 1] = sanitize_text(names[index])
	end
	if #names > max_names then
		shown[#shown + 1] = string.format("+%d more", #names - max_names)
	end
	return table.concat(shown, ", ")
end

local function render_category(entries, label, max_names)
	return string.format("%d %s (%s)", #entries, label, render_names(entries, max_names))
end

local function full_chunks(snapshot, max_names)
	local by_category = {}
	for _, category in ipairs(CATEGORY_ORDER) do
		by_category[category.key] = {}
	end
	for _, repo in ipairs(snapshot.repos or {}) do
		local values = risk_values(repo)
		for _, category in ipairs(CATEGORY_ORDER) do
			if values[category.key] > 0 then
				local entries = by_category[category.key]
				entries[#entries + 1] = { name = repo.name, value = values[category.key] }
			end
		end
	end

	local chunks = {}
	for _, category in ipairs(CATEGORY_ORDER) do
		local entries = by_category[category.key]
		if #entries > 0 then
			chunks[#chunks + 1] = render_category(entries, category.label, max_names)
		end
	end
	return chunks
end

local function index_repos(snapshot)
	local indexed = {}
	for _, repo in ipairs((snapshot or {}).repos or {}) do
		indexed[repo_id(repo)] = repo
	end
	return indexed
end

--- Compare risk values by stable repository path, keeping new, changed, and
--- resolved states distinct so equal aggregate counts cannot cancel out.
local function delta_groups(current, previous)
	local groups = { new = {}, changed = {}, resolved = {} }
	for _, state in ipairs({ "new", "changed", "resolved" }) do
		for _, category in ipairs(CATEGORY_ORDER) do
			groups[state][category.key] = {}
		end
	end

	local current_repos = index_repos(current)
	local previous_repos = index_repos(previous)
	for id, repo in pairs(current_repos) do
		local before = previous_repos[id]
		local current_values = risk_values(repo)
		local previous_values = before and risk_values(before) or {}
		for _, category in ipairs(CATEGORY_ORDER) do
			local now = current_values[category.key] or 0
			local then_value = previous_values[category.key] or 0
			local state
			if then_value == 0 and now > 0 then
				state = "new"
			elseif then_value > 0 and now == 0 then
				state = "resolved"
			elseif then_value > 0 and now > 0 and then_value ~= now then
				state = "changed"
			end
			if state then
				local entries = groups[state][category.key]
				entries[#entries + 1] = { name = repo.name, value = now }
			end
		end
	end

	local missing = {}
	for id, repo in pairs(previous_repos) do
		if not current_repos[id] then
			missing[#missing + 1] = { name = repo.name }
		end
	end
	return groups, missing
end

local function delta_chunks(current, previous, max_names)
	local groups, missing = delta_groups(current, previous)
	local chunks = {}
	for _, state in ipairs({ "new", "changed", "resolved" }) do
		local state_chunks = {}
		for _, category in ipairs(CATEGORY_ORDER) do
			local entries = groups[state][category.key]
			if #entries > 0 then
				state_chunks[#state_chunks + 1] = render_category(entries, category.label, max_names)
			end
		end
		if #state_chunks > 0 then
			state_chunks[1] = state .. ": " .. state_chunks[1]
			for _, chunk in ipairs(state_chunks) do
				chunks[#chunks + 1] = chunk
			end
		end
	end
	if #missing > 0 then
		chunks[#chunks + 1] = "missing: " .. render_category(missing, "repo", max_names)
	end
	return chunks
end

--- Render the action-focused scalar summary from already-collected JSON data.
--- With a previous snapshot it emits only value-sensitive deltas by default.
function M.render_one_line(snapshot, previous, options)
	options = options or {}
	local max_names = tonumber(options.max_names) or 4
	if max_names < 1 then max_names = 1 end

	local chunks
	if options.full or not previous then
		chunks = full_chunks(snapshot, max_names)
		if #chunks == 0 then return "No Tier 1 fleet risks." end
	else
		chunks = delta_chunks(snapshot, previous, max_names)
		if #chunks == 0 then return "No fleet status changes." end
	end
	return table.concat(chunks, " · ")
end

local function plural(value, singular, plural_form)
	if value == 1 then return "1 " .. singular end
	return tostring(value) .. " " .. (plural_form or singular .. "s")
end

local function action_details(repo)
	local values = risk_values(repo)
	local details = {}
	if values.unpushed > 0 then
		details[#details + 1] = plural(values.unpushed, "unpushed", "unpushed")
	end
	if values.orphaned > 0 then
		details[#details + 1] = plural(values.orphaned, "orphaned commit")
	end
	if values.no_remote > 0 then details[#details + 1] = "no remote" end
	if values.modified > 0 then
		details[#details + 1] = plural(values.modified, "modified", "modified")
	end
	if values.staged > 0 then details[#details + 1] = plural(values.staged, "staged", "staged") end
	if values.untracked > 0 then
		details[#details + 1] = plural(values.untracked, "untracked", "untracked")
	end
	if values.stashed > 0 then details[#details + 1] = plural(values.stashed, "stash", "stashes") end
	return details
end

local function context_details(repo)
	local details = {}
	if repo.detached_head then
		if repo.orphaned_status == "unknown" then
			details[#details + 1] = "detached (orphan check unknown)"
		elseif #(repo.orphaned_commits or {}) == 0 then
			details[#details + 1] = "detached (safe)"
		else
			details[#details + 1] = "detached"
		end
	end
	local behind = 0
	local names = {}
	for _, branch in ipairs(repo.branches or {}) do
		local count = tonumber(branch.behind) or 0
		if count > 0 then
			behind = behind + count
			names[#names + 1] = branch.name
		end
	end
	if behind > 0 then
		table.sort(names)
		details[#details + 1] = plural(behind, "behind", "behind")
			.. " (" .. table.concat(names, ", ") .. ")"
	end
	return details
end

local function markdown_escape(value)
	if value == nil or value == cjson.null then return "—" end
	value = sanitize_text(value)
	return value:gsub("\\", "\\\\"):gsub("|", "\\|")
end

local function markdown_row(repo, action, context)
	return string.format(
		"| %s | %s | %s | %s |",
		markdown_escape(repo.name),
		markdown_escape(#action > 0 and table.concat(action, "; ") or "—"),
		markdown_escape(#context > 0 and table.concat(context, "; ") or "—"),
		markdown_escape(repo.last_commit_date)
	)
end

local function markdown_ref(value)
	local text = tostring(value or "—")
	if text:match("^[0-9a-fA-F]+$") and #text == 40 then
		return text:sub(1, 8) .. "…"
	end
	return markdown_escape(text)
end

local function slow_drift_lines(repos)
	local fork_rows, pin_rows, ci_rows = {}, {}, {}
	for _, repo in ipairs(repos) do
		local fork = repo.fork_drift
		if fork and (fork.status == "unknown"
			or (fork.status == "known" and fork.relation ~= "even")) then
			fork_rows[#fork_rows + 1] = string.format(
				"| %s | %s | %s | %s | %s |",
				markdown_escape(repo.name),
				markdown_escape(fork.status == "known" and fork.relation or "unknown"),
				markdown_escape(fork.parent),
				markdown_escape(fork.ahead),
				markdown_escape(fork.behind)
			)
		end
		for _, pin in ipairs(repo.pin_drift or {}) do
			if pin.status ~= "current" then
				local locked = pin.pinned_sha or pin.locked_version
				or pin.pinned_epoch or "—"
				local upstream = pin.head_sha or pin.upstream_version or "—"
				local drift = {}
				if pin.commits_stale ~= nil and pin.commits_stale ~= cjson.null then
					drift[#drift + 1] = tostring(pin.commits_stale) .. " commits"
				end
				if pin.days_stale ~= nil and pin.days_stale ~= cjson.null then
					drift[#drift + 1] = tostring(pin.days_stale) .. " days"
				end
				pin_rows[#pin_rows + 1] = string.format(
					"| %s | %s / %s | %s | %s | %s | %s |",
					markdown_escape(repo.name),
					markdown_escape(pin.kind),
					markdown_escape(pin.name),
					markdown_escape(pin.status),
					markdown_ref(locked),
					markdown_ref(upstream),
					markdown_escape(#drift > 0 and table.concat(drift, ", ") or pin.reason)
				)
			end
		end
		local ci = repo.mechatron
		local last_status = ci and ci.last_result and ci.last_result ~= cjson.null
			and ci.last_result.status or nil
		if ci and (ci.status == "unknown" or ci.missing_targets_manifest
			or (last_status and last_status ~= "success")) then
			ci_rows[#ci_rows + 1] = string.format(
				"| %s | %s | %s | %s |",
				markdown_escape(repo.name),
				ci.missing_targets_manifest and "missing" or "present",
				markdown_escape(ci.status),
				markdown_escape(last_status)
			)
		end
	end
	if #fork_rows == 0 and #pin_rows == 0 and #ci_rows == 0 then return {} end

	local lines = { "", "## Slow drift (Tier 3–5)" }
	if #fork_rows > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "### Fork drift"
		lines[#lines + 1] = ""
		lines[#lines + 1] = "| Repository | State | Parent | Ahead | Behind |"
		lines[#lines + 1] = "|---|---|---|---:|---:|"
		for _, row in ipairs(fork_rows) do lines[#lines + 1] = row end
	end
	if #pin_rows > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "### Pinned inputs"
		lines[#lines + 1] = ""
		lines[#lines + 1] = "| Repository | Ecosystem / input | State | Locked | Upstream | Drift |"
		lines[#lines + 1] = "|---|---|---|---|---|---|"
		for _, row in ipairs(pin_rows) do lines[#lines + 1] = row end
	end
	if #ci_rows > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "### Mechatron Prime"
		lines[#lines + 1] = ""
		lines[#lines + 1] = "| Repository | Targets manifest | Provider | Last result |"
		lines[#lines + 1] = "|---|---|---|---|"
		for _, row in ipairs(ci_rows) do lines[#lines + 1] = row end
	end
	return lines
end

--- Render a terminal-readable daily report from a snapshot, separating urgent
--- action from cosmetic detached/sync context so clean repositories stay quiet.
function M.render_markdown(snapshot, previous)
	local lines = {
		"# Fleet status",
		"",
		"Collected: " .. tostring(snapshot.collected_at or "unknown"),
		"Roots: " .. markdown_escape(table.concat(snapshot.roots or {}, ", ")),
		"",
		"## Action summary",
		"",
		M.render_one_line(snapshot, nil, { full = true }),
	}
	if previous then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "## Changes since previous run"
		lines[#lines + 1] = ""
		lines[#lines + 1] = M.render_one_line(snapshot, previous)
	end

	local repos = {}
	for _, repo in ipairs(snapshot.repos or {}) do repos[#repos + 1] = repo end
	table.sort(repos, function(left, right) return left.name < right.name end)
	local action_rows, context_rows, healthy = {}, {}, {}
	for _, repo in ipairs(repos) do
		local action = action_details(repo)
		local context = context_details(repo)
		if #action > 0 then
			action_rows[#action_rows + 1] = markdown_row(repo, action, context)
		elseif #context > 0 then
			context_rows[#context_rows + 1] = markdown_row(repo, action, context)
		else
			healthy[#healthy + 1] = repo.name
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "## Immediate action"
	lines[#lines + 1] = ""
	if #action_rows == 0 then
		lines[#lines + 1] = "No repositories need immediate action."
	else
		lines[#lines + 1] = "| Repository | Action | Sync / context | Last commit |"
		lines[#lines + 1] = "|---|---|---|---|"
		for _, row in ipairs(action_rows) do lines[#lines + 1] = row end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "## Informational"
	lines[#lines + 1] = ""
	if #context_rows == 0 then
		lines[#lines + 1] = "No cosmetic detached or behind-only repositories."
	else
		lines[#lines + 1] = "| Repository | Action | Sync / context | Last commit |"
		lines[#lines + 1] = "|---|---|---|---|"
		for _, row in ipairs(context_rows) do lines[#lines + 1] = row end
	end

	table.sort(healthy)
	lines[#lines + 1] = ""
	if #healthy == 0 then
		lines[#lines + 1] = "Healthy: none."
	else
		lines[#lines + 1] = string.format(
			"Healthy: %d (%s).",
			#healthy,
			table.concat(healthy, ", ")
		)
	end
	for _, line in ipairs(slow_drift_lines(repos)) do lines[#lines + 1] = line end
	return table.concat(lines, "\n")
end

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function trim(value)
	local trimmed = (value or ""):gsub("%s+$", "")
	return trimmed
end

local function run_command(command)
	local marker = "__FLEET_STATUS_EXIT__"
	local wrapped = command
		.. " 2>/dev/null; fleet_status_exit=$?; printf '\\n"
		.. marker
		.. ":%s\\n' \"$fleet_status_exit\""
	local pipe = io.popen(wrapped, "r")
	if not pipe then return "", false end
	local output = pipe:read("*a") or ""
	pipe:close()
	local body, status = output:match("^(.*)\n" .. marker .. ":(%d+)\n$")
	if not status then return output, false end
	return body, tonumber(status) == 0
end

local function run_git(repo, arguments)
	local git = os.getenv("FLEET_STATUS_GIT") or "git"
	return run_command("LC_ALL=C " .. shell_quote(git) .. " -C "
		.. shell_quote(repo) .. " " .. arguments)
end

--- Parse porcelain-v2 XY records into disjoint staged, worktree-modified, and
--- untracked counts; one path may intentionally count in both XY dimensions.
local function collect_dirty(repo)
	local output, ok = run_git(repo, "status --porcelain=v2 --branch --untracked-files=all")
	if not ok then
		return {
			status = "unknown",
			staged = cjson.null,
			modified = cjson.null,
			untracked = cjson.null,
		}
	end
	local dirty = { status = "known", staged = 0, modified = 0, untracked = 0 }
	for line in output:gmatch("[^\n]+") do
		if line:sub(1, 2) == "? " then
			dirty.untracked = dirty.untracked + 1
		else
			local xy = line:match("^[12u] ([^ ]+) ")
			if xy then
				if xy:sub(1, 1) ~= "." then dirty.staged = dirty.staged + 1 end
				if xy:sub(2, 2) ~= "." then dirty.modified = dirty.modified + 1 end
			end
		end
	end
	return dirty
end

local function age_days(now_epoch, commit_epoch)
	commit_epoch = tonumber(commit_epoch)
	if not commit_epoch then return cjson.null end
	return math.max(0, math.floor((now_epoch - commit_epoch) / 86400))
end

local function collect_branches(repo, now_epoch)
	local format = "%(refname:short)%09%(upstream:short)%09%(objectname)"
		.. "%09%(committerdate:iso-strict)%09%(committerdate:unix)"
	local output, ok = run_git(repo, "for-each-ref --format=" .. shell_quote(format) .. " refs/heads")
	if not ok then return {}, "unknown" end
	local branches = {}
	for line in output:gmatch("[^\n]+") do
		local name, upstream, sha, commit_date, commit_epoch =
			line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
		if name then
			local ahead, behind = 0, 0
			local sync_status = "no_upstream"
			if upstream ~= "" then
				local counts, ok = run_git(
					repo,
					"rev-list --left-right --count "
						.. shell_quote(name .. "..." .. upstream)
				)
				if ok then
					ahead, behind = counts:match("^(%d+)%s+(%d+)")
					ahead, behind = tonumber(ahead) or 0, tonumber(behind) or 0
					sync_status = "known"
				else
					ahead, behind = cjson.null, cjson.null
					sync_status = "unknown"
				end
			end
			branches[#branches + 1] = {
				name = name,
				upstream = upstream ~= "" and upstream or cjson.null,
				upstream_configured = upstream ~= "",
				ahead = ahead,
				behind = behind,
				sync_status = sync_status,
				head_sha = sha,
				last_commit_date = commit_date ~= "" and commit_date or cjson.null,
				last_commit_epoch = tonumber(commit_epoch) or cjson.null,
				last_commit_age_days = age_days(now_epoch, commit_epoch),
			}
		end
	end
	return branches, "known"
end

local function collect_orphaned_commits(repo, detached, head_sha)
	if not detached or head_sha == cjson.null then return {}, "not_applicable" end
	local output, ok = run_git(repo, "rev-list HEAD --not --branches")
	if not ok then return {}, "unknown" end
	local commits = {}
	for sha in output:gmatch("[0-9a-f]+") do
		commits[#commits + 1] = sha
	end
	return commits, "known"
end

local function basename(path)
	return path:match("([^/]+)/*$") or path
end

local function collect_stash(repo)
	local ref_output, ref_ok = run_git(
		repo,
		"for-each-ref --count=1 --format='%(refname)' refs/stash"
	)
	if not ref_ok then return cjson.null, "unknown" end
	if trim(ref_output) == "" then return 0, "known" end
	local count_output, count_ok =
		run_git(repo, "rev-list --walk-reflogs --count refs/stash")
	if not count_ok then return cjson.null, "unknown" end
	return tonumber(trim(count_output)) or 0, "known"
end

--- Collect one working tree entirely through stable Git plumbing, keeping I/O
--- outside the pure renderers and avoiding OS-specific filesystem constants.
local function collect_repo(repo, now_epoch)
	local head_output, has_head = run_git(repo, "rev-parse --verify HEAD")
	local head_sha = has_head and trim(head_output) or cjson.null
	local branch_output, on_branch = run_git(repo, "symbolic-ref --quiet --short HEAD")
	local branch = on_branch and trim(branch_output) or cjson.null
	local detached = not on_branch and has_head
	local date_output, has_date = run_git(repo, "show -s --format=%cI HEAD")
	local epoch_output, has_epoch = run_git(repo, "show -s --format=%ct HEAD")
	local remotes_output, has_remotes = run_git(repo, "remote")
	local remotes = {}
	for remote in remotes_output:gmatch("[^\n]+") do
		remotes[#remotes + 1] = remote
	end
	local stash_count, stash_status = collect_stash(repo)
	local orphaned_commits, orphaned_status =
		collect_orphaned_commits(repo, detached, head_sha)
	local branches, branches_status = collect_branches(repo, now_epoch)

	return {
		name = basename(repo),
		path = repo,
		dirty = collect_dirty(repo),
		detached_head = detached,
		orphaned_commits = orphaned_commits,
		orphaned_status = orphaned_status,
		no_remote = has_remotes and (#remotes == 0) or cjson.null,
		remote_status = has_remotes and "known" or "unknown",
		remotes = remotes,
		stash_count = stash_count,
		stash_status = stash_status,
		branch = branch,
		head_sha = head_sha,
		last_commit_date = has_date and trim(date_output) or cjson.null,
		last_commit_epoch = has_epoch and (tonumber(trim(epoch_output)) or cjson.null) or cjson.null,
		last_commit_age_days = has_epoch and age_days(now_epoch, trim(epoch_output)) or cjson.null,
		branches = branches,
		branches_status = branches_status,
	}
end

local function discover_repos(root)
	local normalized_root = root:gsub("/+$", "")
	if normalized_root == "" then normalized_root = "/" end
	local find_executable = os.getenv("FLEET_STATUS_FIND") or "find"
	local command = shell_quote(find_executable) .. " " .. shell_quote(root)
		.. " -maxdepth 2 -name .git -print0"
	local output, ok = run_command(command)
	if not ok then return nil, "cannot scan root: " .. root end
	local repos = {}
	for git_marker in output:gmatch("([^%z]+)%z") do
		local repo = git_marker:gsub("/%.git$", "")
		local parent = repo:match("^(.*)/[^/]+$") or "."
		if repo == normalized_root or parent == normalized_root then
			repos[#repos + 1] = repo
		end
	end
	table.sort(repos)
	return repos
end

--- Discover and collect repeatable roots into the versioned Tier-1 JSON schema.
--- Repository paths are de-duplicated when roots overlap.
function M.collect_roots(roots, options)
	options = options or {}
	local max_tier = tonumber(options.max_tier) or 1
	local now_epoch = tonumber(options.now_epoch) or os.time()
	local paths = {}
	local seen = {}
	for _, root in ipairs(roots) do
		local discovered, err = discover_repos(root)
		if not discovered then return nil, err end
		for _, repo in ipairs(discovered) do
			if not seen[repo] then
				seen[repo] = true
				paths[#paths + 1] = repo
			end
		end
	end
	table.sort(paths)

	local repos = {}
	for _, repo in ipairs(paths) do
		local _, valid = run_git(repo, "rev-parse --git-dir")
		if valid then repos[#repos + 1] = collect_repo(repo, now_epoch) end
	end
	local tier_one_health = "known"
	for _, repo in ipairs(repos) do
		if risk_values(repo).unknown > 0 then
			tier_one_health = "partial"
			break
		end
	end
	local tiers = { ["1"] = tier_one_health }
	if max_tier >= 2 then
		tiers["2"] = "known"
		for _, repo in ipairs(repos) do
			if repo.branches_status == "unknown" then
				tiers["2"] = "partial"
				break
			end
		end
	end
	return {
		schema_version = 1,
		collected_at = os.date("!%Y-%m-%dT%H:%M:%SZ", now_epoch),
		collected_at_epoch = now_epoch,
		roots = roots,
		tiers = tiers,
		repos = repos,
	}
end

local function table_is_array(value)
	local count, highest = 0, 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
		count = count + 1
		if key > highest then highest = key end
	end
	return count == highest
end

--- Encode schema data with sorted object keys so successive JSON snapshots are
--- byte-diffable; delegate scalar escaping and validation to mature CJSON.
local function encode_canonical(value)
	if type(value) ~= "table" then return cjson.encode(value) end
	local parts = {}
	if table_is_array(value) then
		for index = 1, #value do parts[index] = encode_canonical(value[index]) end
		return "[" .. table.concat(parts, ",") .. "]"
	end

	local keys = {}
	for key in pairs(value) do
		if type(key) ~= "string" then
			error("JSON object keys must be strings")
		end
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for index, key in ipairs(keys) do
		parts[index] = cjson.encode(key) .. ":" .. encode_canonical(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

function M.encode_json(value)
	return encode_canonical(value)
end

function M.decode_json(value)
	return cjson.decode(value)
end

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local contents = file:read("*a")
	file:close()
	return contents
end

function M.load_json_file(path)
	local contents = read_file(path)
	if not contents then return nil end
	local ok, decoded = pcall(cjson.decode, contents)
	if not ok then return nil, "invalid JSON snapshot: " .. path end
	return decoded, nil, contents
end

--- Replace a state file only after its complete bytes exist beside the target,
--- using same-filesystem rename so interrupted writes preserve the old file.
function M.write_atomic(path, contents)
	local directory = path:match("^(.*)/[^/]+$")
	if not directory then return nil, "state path has no directory: " .. path end
	local _, mkdir_ok = run_command("mkdir -p " .. shell_quote(directory))
	if not mkdir_ok then return nil, "cannot create state directory: " .. directory end
	local temp, temp_ok = run_command("mktemp " .. shell_quote(path .. ".tmp.XXXXXX"))
	temp = trim(temp)
	if not temp_ok or temp == "" then return nil, "cannot create temporary state file for: " .. path end

	local file, open_err = io.open(temp, "wb")
	if not file then
		os.remove(temp)
		return nil, tostring(open_err)
	end
	local write_ok, write_err = file:write(contents)
	local close_ok, close_err = file:close()
	if not write_ok or not close_ok then
		os.remove(temp)
		return nil, tostring(write_err or close_err)
	end
	local renamed, rename_err = os.rename(temp, path)
	if not renamed then
		os.remove(temp)
		return nil, tostring(rename_err)
	end
	return true
end

--- Rotate the prior current JSON into previous.json, then atomically publish
--- the collected snapshot; callers render against the returned prior value.
function M.persist_snapshot(state_dir, snapshot)
	local current_path = state_dir .. "/current.json"
	local previous_path = state_dir .. "/previous.json"
	local previous, load_err, previous_bytes = M.load_json_file(current_path)
	if load_err then return nil, load_err end
	if previous_bytes then
		local ok, err = M.write_atomic(previous_path, previous_bytes)
		if not ok then return nil, err end
	end
	local ok, err = M.write_atomic(current_path, M.encode_json(snapshot) .. "\n")
	if not ok then return nil, err end
	return previous
end

--- Exclude concurrent snapshot/report publishers with portable atomic mkdir;
--- the returned path is an explicit ownership token released by the caller.
function M.acquire_state_lock(state_dir)
	local _, state_ok = run_command("mkdir -p " .. shell_quote(state_dir))
	if not state_ok then return nil, "cannot create state directory: " .. state_dir end
	local lock_path = state_dir .. "/.fleet-status.lock"
	local _, locked = run_command("mkdir " .. shell_quote(lock_path))
	if not locked then return nil, "fleet-status state is locked by another run" end
	return lock_path
end

function M.release_state_lock(lock_path)
	local _, released = run_command("rmdir " .. shell_quote(lock_path))
	if not released then return nil, "cannot release fleet-status state lock" end
	return true
end

local function decode_command_json(command)
	local cache = M.provider_cache
	local cache_path
	if cache and cache.ttl_seconds > 0 then
		local hash = 5381
		for index = 1, #command do
			hash = (hash * 33 + command:byte(index)) % 4294967296
		end
		cache_path = cache.directory .. "/" .. string.format("%08x", hash) .. ".json"
		local record = M.load_json_file(cache_path)
		local record_ttl = record and record.negative
			and math.min(cache.ttl_seconds, 900)
			or cache.ttl_seconds
		if record
			and record.network_cache_version == M.NETWORK_CACHE_VERSION
			and record.command == command
			and tonumber(record.cached_at_epoch)
			and cache.now_epoch - tonumber(record.cached_at_epoch) <= record_ttl then
			return record.response
		end
	end
	local output, ok = run_command(command)
	local decoded_ok, decoded = pcall(cjson.decode, output)
	if not ok or not decoded_ok then
		if cache_path and cache.save then
			M.write_atomic(cache_path, M.encode_json({
				network_cache_version = M.NETWORK_CACHE_VERSION,
				command = command,
				cached_at_epoch = cache.now_epoch,
				negative = true,
				response = cjson.null,
			}) .. "\n")
		end
		return nil
	end
	if cache_path and cache.save then
		M.write_atomic(cache_path, M.encode_json({
			network_cache_version = M.NETWORK_CACHE_VERSION,
			command = command,
			cached_at_epoch = cache.now_epoch,
			response = decoded,
		}) .. "\n")
	end
	return decoded
end

--- Configure a worker-local response cache so repeated provider queries across
--- ecosystems are deduplicated without coupling collectors to provider details.
function M.configure_provider_cache(options)
	M.provider_cache = options
end

local function github_slug(remote_url)
	if not remote_url then return nil end
	local slug = remote_url:match("^git@github%.com:([^/]+/[^/]+)%.git$")
		or remote_url:match("^git@github%.com:([^/]+/[^/]+)$")
		or remote_url:match("^https://github%.com/([^/]+/[^/]+)%.git$")
		or remote_url:match("^https://github%.com/([^/]+/[^/]+)$")
	if not slug then return nil end
	return slug:gsub("%.git$", "")
end

local function provider_command(environment_name, fallback, arguments)
	local executable = os.getenv(environment_name) or fallback
	local timeout = os.getenv("FLEET_STATUS_TIMEOUT")
	if not timeout then
		local discovered, found = run_command("command -v gtimeout || command -v timeout")
		timeout = found and trim(discovered) or nil
	end
	if not timeout or timeout == "" then return "false" end
	local seconds = tonumber(os.getenv("FLEET_STATUS_PROVIDER_TIMEOUT_SECONDS")) or 30
	seconds = math.max(1, math.floor(seconds))
	return shell_quote(timeout) .. " " .. tostring(seconds) .. " "
		.. shell_quote(executable) .. " " .. arguments
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
		local owner, repository = url:match("github%.com/([^/]+)/([^/?#]+)")
		if repository then repository = repository:gsub("%.git$", "") end
		local pinned_sha = url:match("#([0-9a-fA-F][0-9a-fA-F]+)$")
			or url:match("/archive/([0-9a-fA-F]+)%.tar%.gz$")
			or url:match("/archive/([0-9a-fA-F]+)%.zip$")
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
	value = trim(value):gsub("^['\"]", ""):gsub("['\"]$", "")
	return value
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
	local manifest = io.open(repo.path .. "/.mechatron-prime/targets", "rb")
	local missing_manifest = manifest == nil
	if manifest then manifest:close() end
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
	local now_epoch = tonumber(snapshot.collected_at_epoch) or os.time()
	local cache_dir = state_dir .. "/network-cache"
	local provider_cache_dir = cache_dir .. "/provider"
	if save_cache then
		local _, made_cache = run_command("mkdir -p " .. shell_quote(provider_cache_dir))
		if not made_cache then return nil, "cannot create network cache: " .. cache_dir end
	end

	local job_template = save_cache and (cache_dir .. "/jobs.XXXXXX")
		or ((os.getenv("TMPDIR") or "/tmp") .. "/fleet-status-network.XXXXXX")
	local job_dir_output, made_jobs = run_command(
		"mktemp -d " .. shell_quote(job_template)
	)
	local job_dir = trim(job_dir_output)
	if not made_jobs or job_dir == "" then return nil, "cannot create network job directory" end
	local input_path = job_dir .. "/inputs"
	local input = assert(io.open(input_path, "wb"))
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
			if not ok then input:close(); return nil, err end
			input:write(job_path, "\0")
			pending[#pending + 1] = {
				index = index,
				job = job_path,
				output = output_path,
				transient_output = not save_cache,
				network_fingerprint = fingerprint,
			}
		end
	end
	input:close()

	if #pending > 0 then
		local worker = options.worker or ((options.bin_dir or "") .. "/fleet-status-network-worker")
		local xargs = os.getenv("FLEET_STATUS_XARGS") or "xargs"
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
			os.remove(item.job)
			if item.transient_output then os.remove(item.output) end
		end
	end
	os.remove(input_path)
	os.remove(job_dir)

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

local M = {}
local cjson = require("cjson")
if cjson.encode_empty_table_as_object then
	cjson.encode_empty_table_as_object(false)
end

local CATEGORY_ORDER = {
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
		unpushed = ahead,
		orphaned = #(repo.orphaned_commits or {}),
		no_remote = repo.no_remote and 1 or 0,
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

local function render_names(entries, max_names)
	local names = sorted_names(entries)
	local shown = {}
	local limit = math.min(#names, max_names)
	for index = 1, limit do
		shown[#shown + 1] = names[index]
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
		if #(repo.orphaned_commits or {}) == 0 then
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
	value = tostring(value or "—")
	return value:gsub("\\", "\\\\"):gsub("|", "\\|"):gsub("[\r\n]+", " ")
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

--- Render a terminal-readable daily report from a snapshot, separating urgent
--- action from cosmetic detached/sync context so clean repositories stay quiet.
function M.render_markdown(snapshot, previous)
	local lines = {
		"# Fleet status",
		"",
		"Collected: " .. tostring(snapshot.collected_at or "unknown"),
		"Roots: " .. table.concat(snapshot.roots or {}, ", "),
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
	return run_command("LC_ALL=C git -C " .. shell_quote(repo) .. " " .. arguments)
end

--- Parse porcelain-v2 XY records into disjoint staged, worktree-modified, and
--- untracked counts; one path may intentionally count in both XY dimensions.
local function collect_dirty(repo)
	local output = run_git(repo, "status --porcelain=v2 --branch --untracked-files=all")
	local dirty = { staged = 0, modified = 0, untracked = 0 }
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
	local output = run_git(repo, "for-each-ref --format=" .. shell_quote(format) .. " refs/heads")
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
	return branches
end

local function collect_orphaned_commits(repo, detached, head_sha)
	if not detached or head_sha == cjson.null then return {} end
	local output, ok = run_git(repo, "rev-list HEAD --not --branches")
	if not ok then return {} end
	local commits = {}
	for sha in output:gmatch("[0-9a-f]+") do
		commits[#commits + 1] = sha
	end
	return commits
end

local function basename(path)
	return path:match("([^/]+)/*$") or path
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
	local remotes_output = run_git(repo, "remote")
	local remotes = {}
	for remote in remotes_output:gmatch("[^\n]+") do
		remotes[#remotes + 1] = remote
	end
	local stash_output, has_stash = run_git(repo, "rev-list --walk-reflogs --count refs/stash")

	return {
		name = basename(repo),
		path = repo,
		dirty = collect_dirty(repo),
		detached_head = detached,
		orphaned_commits = collect_orphaned_commits(repo, detached, head_sha),
		no_remote = #remotes == 0,
		remotes = remotes,
		stash_count = has_stash and (tonumber(trim(stash_output)) or 0) or 0,
		branch = branch,
		head_sha = head_sha,
		last_commit_date = has_date and trim(date_output) or cjson.null,
		last_commit_epoch = has_epoch and (tonumber(trim(epoch_output)) or cjson.null) or cjson.null,
		last_commit_age_days = has_epoch and age_days(now_epoch, trim(epoch_output)) or cjson.null,
		branches = collect_branches(repo, now_epoch),
	}
end

local function discover_repos(root)
	local normalized_root = root:gsub("/+$", "")
	if normalized_root == "" then normalized_root = "/" end
	local command = "find " .. shell_quote(root)
		.. " -path /nix/store -prune -o -name .git -print0 -prune"
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
	local tiers = { ["1"] = "known" }
	if max_tier >= 2 then tiers["2"] = "known" end
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

return M

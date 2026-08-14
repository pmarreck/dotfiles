local cjson = require("cjson")

--- Construct the local Git adapter from an injected process/filesystem port.
local function new(runtime)
local M = {}
local run_git = runtime.run_git
local run_command = runtime.run_command
local shell_quote = runtime.shell_quote
local trim = runtime.trim
local file_times = runtime.file_times

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

local function collect_inbox(repo, now_epoch)
	local inbox_path = repo .. "/inbox"
	local _, exists = run_command("test -d " .. shell_quote(inbox_path))
	if not exists then
		return { status = "known", count = 0, oldest_epoch = cjson.null,
			oldest_age_seconds = cjson.null }
	end
	local find = os.getenv("FLEET_STATUS_FIND") or "find"
	local output, ok = run_command(
		shell_quote(find) .. " " .. shell_quote(inbox_path)
			.. " ! -path " .. shell_quote(inbox_path)
			.. " -prune -type f -name '*.md' ! -name '.*' -print0"
	)
	if not ok then
		return { status = "unknown", count = cjson.null,
			oldest_epoch = cjson.null, oldest_age_seconds = cjson.null }
	end
	local count, oldest, status = 0, nil, "known"
	for path in output:gmatch("([^%z]+)%z") do
		count = count + 1
		local _, mtime = file_times(path)
		if mtime then
			if not oldest or mtime < oldest then oldest = mtime end
		else
			status = "unknown"
		end
	end
	return {
		status = status,
		count = count,
		oldest_epoch = oldest or cjson.null,
		oldest_age_seconds = oldest and math.max(0, now_epoch - oldest) or cjson.null,
	}
end

local function collect_worktrees(repo, now_epoch)
	local output, ok = run_git(repo, "worktree list --porcelain -z")
	if not ok then return {}, "unknown" end
	local all_records, current = {}, nil
	local function finish()
		if not current then return end
		if current.path and current.path ~= "" then
			all_records[#all_records + 1] = current
		end
		current = nil
	end
	for field in (output .. "\0"):gmatch("([^%z]*)%z") do
		if field == "" then
			finish()
		elseif field:sub(1, 9) == "worktree " then
			finish()
			current = { path = field:sub(10) }
		elseif current and field:sub(1, 5) == "HEAD " then
			current.head_sha = field:sub(6)
		elseif current and field:sub(1, 7) == "branch " then
			current.branch = field:sub(8):gsub("^refs/heads/", "")
		elseif current and field == "detached" then
			current.detached = true
		elseif current and field:sub(1, 9) == "prunable " then
			current.prunable = field:sub(10)
		end
	end
	finish()
	local scanned_path = repo:gsub("/+$", "")
	local primary_path = all_records[1]
		and all_records[1].path:gsub("/+$", "") or nil
	if not primary_path then return {}, "unknown" end
	if primary_path ~= scanned_path then return {}, "known" end
	local records = {}
	for index = 2, #all_records do records[#records + 1] = all_records[index] end
	local status = "known"
	for _, worktree in ipairs(records) do
		local epoch, found = run_git(
			repo,
			"show -s --format=%ct " .. shell_quote(worktree.head_sha or "")
		)
		local value = found and tonumber(trim(epoch)) or nil
		worktree.last_commit_epoch = value or cjson.null
		worktree.last_commit_age_days = value
			and math.max(0, math.floor((now_epoch - value) / 86400)) or cjson.null
		if not value then status = "partial" end
	end
	return records, status
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
	local worktrees, worktrees_status = collect_worktrees(repo, now_epoch)

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
		worktrees = worktrees,
		worktrees_status = worktrees_status,
		inbox = collect_inbox(repo, now_epoch),
	}
end

local function discover_repos(root)
	local normalized_root = root:gsub("/+$", "")
	if normalized_root == "" then normalized_root = "/" end
	local find_executable = os.getenv("FLEET_STATUS_FIND") or "find"
	local command = shell_quote(find_executable) .. " " .. shell_quote(root)
		.. " ! -path " .. shell_quote(root) .. " -prune -type d -print0"
	local output, ok = run_command(command)
	if not ok then return nil, "cannot scan root: " .. root end
	local candidates = { normalized_root }
	for candidate in output:gmatch("([^%z]+)%z") do
		candidates[#candidates + 1] = candidate
	end
	local repos = {}
	for _, candidate in ipairs(candidates) do
		local _, is_repo =
			run_command("test -e " .. shell_quote(candidate .. "/.git"))
		if is_repo then
			repos[#repos + 1] = candidate
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
		if repo.dirty.status == "unknown"
			or repo.orphaned_status == "unknown"
			or repo.branches_status == "unknown"
			or repo.remote_status == "unknown"
			or repo.stash_status == "unknown"
			or repo.worktrees_status ~= "known"
			or repo.inbox.status ~= "known" then
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

return M
end

return { new = new }

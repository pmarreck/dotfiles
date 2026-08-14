local M = {
	DEFAULT_THRESHOLDS = {
		fork_behind_commits = 50,
		fork_common_ancestor_seconds = 90 * 24 * 60 * 60,
		dirty_files = 10,
		worktree_idle_seconds = 7 * 24 * 60 * 60,
		inbox_messages = 1,
		inbox_oldest_seconds = 24 * 60 * 60,
	},
}

local function number(value)
	return tonumber(value)
end

local function plural(value, singular)
	return tostring(value) .. " " .. singular .. (value == 1 and "" or "s")
end

local function thresholds(overrides)
	local result = {}
	for key, value in pairs(M.DEFAULT_THRESHOLDS) do result[key] = value end
	for key, value in pairs(overrides or {}) do result[key] = tonumber(value) or result[key] end
	return result
end

--- Classify measured fleet risks using only snapshot facts and injected limits.
function M.classify(snapshot, overrides)
	local limits = thresholds(overrides)
	local now_epoch = assert(tonumber(snapshot.collected_at_epoch),
		"attention classifier requires collected_at_epoch")
	local entries = {}
	for _, repo in ipairs(snapshot.repos or {}) do
		local reasons = {}
		local fork = repo.fork_drift or {}
		local behind = number(fork.behind)
		if fork.status == "known" and behind and behind >= limits.fork_behind_commits then
			reasons[#reasons + 1] = "fork: " .. plural(behind, "commit") .. " behind"
		end
		local common_epoch = number(fork.last_common_commit_epoch)
		if fork.status == "known" and common_epoch
			and now_epoch - common_epoch >= limits.fork_common_ancestor_seconds then
			local days = math.floor((now_epoch - common_epoch) / 86400)
			reasons[#reasons + 1] = "fork: common ancestor " .. plural(days, "day") .. " old"
		end

		local dirty = repo.dirty or {}
		local staged = number(dirty.staged) or 0
		local modified = number(dirty.modified) or 0
		local untracked = number(dirty.untracked) or 0
		local dirty_total = staged + modified + untracked
		if dirty.status ~= "unknown" and dirty_total >= limits.dirty_files then
			reasons[#reasons + 1] = string.format(
				"dirty: %d files (%d staged, %d modified, %d untracked)",
				dirty_total, staged, modified, untracked
			)
		end

		for _, worktree in ipairs(repo.worktrees or {}) do
			local commit_epoch = number(worktree.last_commit_epoch)
			if commit_epoch and now_epoch - commit_epoch > limits.worktree_idle_seconds then
				local days = math.floor((now_epoch - commit_epoch) / 86400)
				local branch = worktree.branch or "detached"
				reasons[#reasons + 1] = string.format(
					"worktree: %s idle %s (%s)",
					branch,
					plural(days, "day"),
					worktree.path or "unknown path"
				)
			end
		end

		local inbox = repo.inbox or {}
		local count = number(inbox.count) or 0
		local oldest = number(inbox.oldest_age_seconds)
		if inbox.status ~= "unknown"
			and (count > limits.inbox_messages
				or (oldest and oldest > limits.inbox_oldest_seconds)) then
			local reason = "inbox: " .. plural(count, "message")
			if oldest and oldest > limits.inbox_oldest_seconds then
				reason = reason .. ", oldest " .. plural(math.floor(oldest / 86400), "day")
			end
			reasons[#reasons + 1] = reason
		end

		local profile = repo.repository_profile
		if type(profile) == "table" then
			if profile.status == "unknown" then
				reasons[#reasons + 1] = "documents: inspection unknown"
			else
				if not (profile.readme and profile.readme.present) then
					reasons[#reasons + 1] = "documents: README.md missing"
				end
				if not (profile.license and profile.license.present) then
					reasons[#reasons + 1] = "documents: LICENSE missing"
				end
			end
		end

		local ci = repo.mechatron
		if type(ci) == "table" then
			if ci.configuration == "badge_only" then
				reasons[#reasons + 1] = "Mechatron: incomplete configuration (badge only)"
			elseif ci.configuration == "targets_only" then
				reasons[#reasons + 1] = "Mechatron: incomplete configuration (targets only)"
			elseif ci.configuration == "complete"
				and (ci.head_status == "failing" or ci.head_status == "not_run"
					or ci.head_status == "unknown") then
				reasons[#reasons + 1] = "Mechatron: current HEAD " .. ci.head_status
			end
		end

		if #reasons > 0 then entries[#entries + 1] = { name = repo.name, reasons = reasons } end
	end
	table.sort(entries, function(left, right) return left.name < right.name end)
	return entries
end

return M

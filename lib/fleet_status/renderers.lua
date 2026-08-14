local cjson = require("cjson")
local M = {}
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
			or repo.stash_status == "unknown"
			or (repo.worktrees_status and repo.worktrees_status ~= "known")
			or (repo.inbox and repo.inbox.status ~= "known")) and 1 or 0,
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

local function document_value(profile, field)
	if type(profile) ~= "table" or profile.status == "unknown" then return "unknown" end
	local document = profile[field]
	if type(document) ~= "table" or not document.present then return "missing" end
	return document.filename or "present"
end

local function display_state(value)
	return tostring(value or "unknown"):gsub("_", " ")
end

--- Project repository readiness into stable scalar rows before presentation.
--- This keeps the table renderer free of policy and missing-field inference.
function M.readiness_rows(repos)
	local rows = {}
	for _, repo in ipairs(repos or {}) do
		local profile = repo.repository_profile
		local ci = repo.mechatron
		rows[#rows + 1] = {
			repository = repo.name,
			readme = document_value(profile, "readme"),
			license = document_value(profile, "license"),
			license_type = profile and profile.license and profile.license.type or "unknown",
			primary_language = profile and profile.primary_language
				and profile.primary_language.name or "unknown",
			mechatron = ci and display_state(
				ci.configuration == "complete" and "configured" or ci.configuration
			) or "unknown",
			head_status = ci and display_state(ci.head_status) or "unknown",
		}
	end
	table.sort(rows, function(left, right) return left.repository < right.repository end)
	return rows
end

local function readiness_lines(repos)
	local measured = false
	for _, repo in ipairs(repos or {}) do
		if repo.repository_profile or repo.mechatron then
			measured = true
			break
		end
	end
	if not measured then return {} end
	local lines = {
		"",
		"## Repository readiness",
		"",
		"| Repository | README | License | License type | Primary language | Mechatron | Current HEAD |",
		"|---|---|---|---|---|---|---|",
	}
	for _, row in ipairs(M.readiness_rows(repos)) do
		lines[#lines + 1] = string.format(
			"| %s | %s | %s | %s | %s | %s | %s |",
			markdown_escape(row.repository),
			markdown_escape(row.readme),
			markdown_escape(row.license),
			markdown_escape(row.license_type),
			markdown_escape(row.primary_language),
			markdown_escape(row.mechatron),
			markdown_escape(row.head_status)
		)
	end
	return lines
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
function M.render_markdown(snapshot, previous, options)
	options = options or {}
	local lines = {
		"# Fleet status",
		"",
		"Collected: " .. tostring(snapshot.collected_at or "unknown"),
		"Roots: " .. markdown_escape(table.concat(snapshot.roots or {}, ", ")),
	}
	local attention_entries = options.classify_attention
		and options.classify_attention(snapshot, options.attention_thresholds) or {}
	lines[#lines + 1] = ""
	lines[#lines + 1] = "## Repos Requiring Special Attention"
	lines[#lines + 1] = ""
	if #attention_entries == 0 then
		lines[#lines + 1] = "No repositories require special attention."
	else
		lines[#lines + 1] = "| Repository | Measured reason |"
		lines[#lines + 1] = "|---|---|"
		for _, entry in ipairs(attention_entries) do
			lines[#lines + 1] = string.format(
				"| %s | %s |",
				markdown_escape(entry.name),
				markdown_escape(table.concat(entry.reasons, "; "))
			)
		end
	end
	for _, line in ipairs(readiness_lines(snapshot.repos or {})) do
		lines[#lines + 1] = line
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "## Action summary"
	lines[#lines + 1] = ""
	lines[#lines + 1] = M.render_one_line(snapshot, nil, { full = true })
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

return M

local M = {}

local day_seconds = 24 * 60 * 60
local maximum_interval_days = 15

function M.interval_days(commit_age_days)
	local age = tonumber(commit_age_days)
	if not age or age < 0 then return 1 end
	return math.min(maximum_interval_days, math.floor(age / 2) + 1)
end

--- A successful fetch starts a bounded interval; the stable slot only spreads
--- repositories with no prior fetch record over their first interval.
function M.initial_due_epoch(now_epoch, commit_age_days, slot)
	local interval = M.interval_days(commit_age_days)
	local today = math.floor(now_epoch / day_seconds)
	local wait_days = ((slot or 0) % interval - today % interval + interval) % interval
	return wait_days == 0 and now_epoch or (today + wait_days) * day_seconds
end

function M.due(now_epoch, commit_age_days, last_success_epoch, slot, first_due_epoch)
	local interval = M.interval_days(commit_age_days)
	local previous = tonumber(last_success_epoch)
	if previous then
		return now_epoch < previous or now_epoch - previous >= interval * day_seconds
	end
	if tonumber(first_due_epoch) and now_epoch >= tonumber(first_due_epoch) then return true end
	return math.floor(now_epoch / day_seconds) % interval == (slot or 0) % interval
end

local document_names = {
	license = true, licence = true, copying = true,
	readme = true, changelog = true, changes = true,
	contributing = true, authors = true, notice = true,
}
local document_extensions = {
	md = true, mdx = true, rst = true, adoc = true,
	org = true, txt = true,
}

function M.is_document(path)
	local name = path:match("([^/]+)$") or path
	local lower = name:lower()
	local stem, extension = lower:match("^(.*)%.([^.]*)$")
	if document_extensions[extension] then return true end
	return document_names[stem or lower] == true
end

function M.classify_paths(paths)
	local result = { documentation = 0, non_documentation = 0 }
	for _, path in ipairs(paths) do
		if M.is_document(path) then
			result.documentation = result.documentation + 1
		else
			result.non_documentation = result.non_documentation + 1
		end
	end
	return result
end

--- Fairly drain first-run backlog before revisiting already-fetched remotes.
--- A stable key breaks ties without tying priority to directory enumeration.
function M.select_due(candidates, maximum)
	local ordered = {}
	for index, candidate in ipairs(candidates) do ordered[index] = candidate end
	table.sort(ordered, function(left, right)
		local a = tonumber(left.last_success_epoch) or -math.huge
		local b = tonumber(right.last_success_epoch) or -math.huge
		if a ~= b then return a < b end
		return tostring(left.key) < tostring(right.key)
	end)
	local chosen, deferred = {}, {}
	for index, candidate in ipairs(ordered) do
		if index <= maximum then
			chosen[#chosen + 1] = candidate
		else
			deferred[#deferred + 1] = candidate
		end
	end
	return chosen, deferred
end

local function cell(value)
	return tostring(value or "—"):gsub("|", "\\|"):gsub("\n", " ")
end

function M.render_history(datetime, results, summary)
	local fetches_due = 0
	local attempted, deferred = 0, 0
	for _, result in ipairs(results) do
		if result.status ~= "not due" and result.status ~= "no remote" then
			fetches_due = fetches_due + 1
			if result.status == "deferred" then
				deferred = deferred + 1
			elseif result.status ~= "due" then
				attempted = attempted + 1
			end
		end
	end
	local lines = {
		"<!-- repo-maintenance:begin -->",
		"## " .. datetime,
		"",
		fetches_due == 0 and "No repositories due." or (
			"Fetches due: " .. fetches_due .. "; attempted: " .. attempted
			.. "; deferred: " .. deferred .. "."
		),
		"",
		"Fleet: " .. (summary or "unknown"),
		"",
		"| Repository | Fetch | Remote(s) | Non-doc dirty files |",
		"|---|---|---|---:|",
	}
	for _, result in ipairs(results) do
		lines[#lines + 1] = "| " .. cell(result.name)
			.. " | " .. cell(result.status)
			.. " | " .. cell(result.remotes)
			.. " | " .. cell(result.non_documentation) .. " |"
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "<!-- repo-maintenance:end -->"
	return table.concat(lines, "\n") .. "\n"
end

return M

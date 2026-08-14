local M = {
	DAY_SECONDS = 24 * 60 * 60,
	WEEK_SECONDS = 7 * 24 * 60 * 60,
}

local function maximum_epoch(current, candidate)
	candidate = tonumber(candidate)
	if not candidate then return current end
	if not current or candidate > current then return candidate end
	return current
end

--- Find the newest commit on any local branch without reading the host clock.
function M.latest_local_activity_epoch(repo)
	local latest = maximum_epoch(nil, repo and repo.last_commit_epoch)
	for _, branch in ipairs((repo and repo.branches) or {}) do
		latest = maximum_epoch(latest, branch.last_commit_epoch)
	end
	return latest
end

local function leap_year(year)
	return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

--- Parse canonical GitHub UTC timestamps without consulting locale or a clock.
function M.parse_utc_timestamp(timestamp)
	if type(timestamp) ~= "string" then return nil end
	local year, month, day, hour, minute, second = timestamp:match(
		"^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$"
	)
	year, month, day = tonumber(year), tonumber(month), tonumber(day)
	hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
	if not year or month < 1 or month > 12 or hour > 23 or minute > 59 or second > 60 then
		return nil
	end
	local month_days = { 31, leap_year(year) and 29 or 28, 31, 30, 31, 30,
		31, 31, 30, 31, 30, 31 }
	if day < 1 or day > month_days[month] then return nil end

	local adjusted_year = year - (month <= 2 and 1 or 0)
	local era = math.floor(adjusted_year / 400)
	local year_of_era = adjusted_year - era * 400
	local shifted_month = month + (month > 2 and -3 or 9)
	local day_of_year = math.floor((153 * shifted_month + 2) / 5) + day - 1
	local day_of_era = year_of_era * 365 + math.floor(year_of_era / 4)
		- math.floor(year_of_era / 100) + day_of_year
	local days_since_epoch = era * 146097 + day_of_era - 719468
	return days_since_epoch * 86400 + hour * 3600 + minute * 60 + second
end

local function github_timestamp_is_recent(timestamp, now_epoch, week_seconds)
	local epoch = M.parse_utc_timestamp(timestamp)
	return epoch ~= nil and epoch >= now_epoch - week_seconds
end

--- Choose carry, lightweight probe, or full refresh from injected timestamps.
function M.network_action(now_epoch, repo, cached, fingerprint, options)
	options = options or {}
	local day = tonumber(options.day_seconds) or M.DAY_SECONDS
	local week = tonumber(options.week_seconds) or M.WEEK_SECONDS
	now_epoch = assert(tonumber(now_epoch), "network scheduler requires now_epoch")
	if type(cached) ~= "table" then return "full", "missing-cache", 0 end
	if cached.network_fingerprint ~= fingerprint then
		return "full", "local-input-changed", 0
	end

	local checked_at = tonumber(cached.cached_at_epoch)
	if not checked_at then return "full", "missing-observation-time", 0 end
	if now_epoch < checked_at then return "full", "clock-skew", 0 end

	local cutoff_epoch = now_epoch - week
	local local_activity = M.latest_local_activity_epoch(repo)
	local fork = type(cached.fork_drift) == "table" and cached.fork_drift or {}
	local local_hot = local_activity and local_activity >= cutoff_epoch
	local upstream_hot = github_timestamp_is_recent(
		fork.parent_pushed_at,
		now_epoch,
		week
	)
	if local_hot or upstream_hot then
		if now_epoch - checked_at >= day then
			return "full",
				local_hot and "daily-local-activity" or "daily-upstream-activity",
				day
		end
		return "carry", "hot-cache-current", day
	end

	local probed_at = tonumber(cached.upstream_probed_at_epoch) or checked_at
	if now_epoch < probed_at then return "full", "clock-skew", 0 end
	if fork.status == "known" and type(fork.parent) == "string" then
		if now_epoch - probed_at >= week then
			return "probe", "weekly-upstream-probe", week
		end
		return "carry", "quiet-probe-current", week
	end
	if fork.status == "unknown" and now_epoch - checked_at >= week then
		return "full", "weekly-classification-retry", week
	end
	return "carry", "quiet-nonfork", week
end

return M

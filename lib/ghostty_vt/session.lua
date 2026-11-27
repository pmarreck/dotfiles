-- A program running in a headless Ghostty terminal: every byte it writes goes
-- through libghostty-vt, and every reply the terminal owes goes back to it, so
-- queries are answered the way a real Ghostty tab answers them.
local terminal = require("ghostty_vt.terminal")
local pty = require("ghostty_vt.pty")

local M = {}

local Session = {}
Session.__index = Session

local function monotonic_seconds()
	local ffi = require("ffi")
	pcall(ffi.cdef, [[
		struct ghostty_vt_timespec { long tv_sec; long tv_nsec; };
		int clock_gettime(int clock_id, struct ghostty_vt_timespec *tp);
	]])
	local now = ffi.new("struct ghostty_vt_timespec")
	ffi.C.clock_gettime(ffi.os == "OSX" and 6 or 1, now) -- CLOCK_MONOTONIC (macOS: 6)
	return tonumber(now.tv_sec) + tonumber(now.tv_nsec) / 1e9
end

-- options: argv, env (list of NAME=value), cols, rows.
function M.start(options)
	local cols, rows = options.cols or 100, options.rows or 40
	local self = setmetatable({
		term = terminal.new(cols, rows, 8, 16),
		transcript = {},
	}, Session)
	self.process = pty.spawn(options.argv, options.env, cols, rows)
	return self
end

-- Move whatever the program has written within `timeout_ms` into the
-- terminal and answer its queries. Returns false once the terminal closed.
function Session:pump(timeout_ms)
	local bytes = self.process:read(timeout_ms)
	if bytes == nil then return false end
	if #bytes > 0 then
		self.transcript[#self.transcript + 1] = bytes
		self.term:write(bytes)
		local replies = self.term:take_replies()
		if #replies > 0 then self.process:write(replies) end
	end
	return true
end

-- Pump until `predicate(session)` holds or `deadline_seconds` pass. A deadline
-- bounds a hung shell; reaching it is a failure for the caller to report.
function Session:wait_for(predicate, deadline_seconds)
	local finish = monotonic_seconds() + deadline_seconds
	while true do
		if predicate(self) then return true end
		if monotonic_seconds() >= finish then return false end
		if not self:pump(50) then return predicate(self) end
	end
end

-- Type text as a person would, then pump until the program falls quiet.
function Session:type(text)
	self.process:write(text)
end

function Session:text() return self.term:text() end
function Session:placements() return self.term:placements() end
function Session:cursor() return self.term:cursor() end
function Session:raw() return table.concat(self.transcript) end

function Session:close()
	self.process:close()
	self.term:free()
end

return M

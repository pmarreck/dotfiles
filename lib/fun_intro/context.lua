-- The live context the picks run in: the real environment, clock, random
-- source, system adapters, and terminal facts. Tests build their own tables
-- of the same shape instead.
local sys = require("fun_intro.sys")
local rng = require("fun_intro.rng")
local terminal = require("fun_intro.terminal")
local terminfo = require("fun_intro.terminfo")

local M = {}

function M.live(root)
	local env = os.getenv
	local home = env("HOME") or ""
	local cache_home = env("XDG_CACHE_HOME")
	if not cache_home or cache_home == "" then cache_home = home .. "/.cache" end
	local ctx = {
		root = root,
		env = env,
		sys = sys,
		rng = rng.seeded(),
		now = os.time,
		cache_dir = cache_home .. "/dotfiles/fun_intro",
	}
	local function terminfo_text()
		return terminfo.visible_text(terminfo.entry(env("TERM"), env, sys.read))
	end
	-- The terminal emulator is the parent of the shell that started us.
	local function parent_command()
		return sys.process_command(sys.parent_of(sys.getppid()))
	end
	function ctx.image_protocol()
		return terminal.image_protocol(env, terminfo_text, parent_command)
	end
	return ctx
end

return M

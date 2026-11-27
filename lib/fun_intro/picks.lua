-- The intro's picks: one registry naming every pick, its pool, and how it
-- renders. Every pick runs inside this LuaJIT process except fortune (a
-- native program) and mandelbash (a Bash demo, memoized).
--
-- A pick receives a context `ctx` (see context.lua) and returns its output,
-- or nil and a message.
local text = require("fun_intro.text")
local image = require("fun_intro.image")
local mandel = require("fun_intro.mandel")

local M = {}

M.TEXT = {
	"fortune", "warhammer_quote", "bashorg_quote", "chuck", "mandelbash",
	"asciidragon", "just_one_taoup", "times_older_than_samson",
}
M.IMAGE = { "inthebeginning" }

local function data(ctx, relative)
	local path = ctx.root .. "/" .. relative
	local contents = ctx.sys.read(path)
	if not contents then return nil, "cannot read " .. path end
	return contents
end

local function with_data(relative, render)
	return function(ctx)
		local contents, err = data(ctx, relative)
		if not contents then return nil, err end
		return render(contents, ctx)
	end
end

local runners = {
	fortune = function(ctx)
		local path = ctx.sys.find_command("fortune", ctx.env("PATH"))
		if not path then return nil, "Tried to call 'fortune', but it was not defined" end
		local output, status = ctx.sys.run(path)
		if status ~= 0 then return nil, "fortune failed with status " .. tostring(status) end
		return output
	end,
	warhammer_quote = with_data("bin/data/warhammer_quotes.txt", function(quotes, ctx)
		return text.warhammer(quotes, ctx.rng)
	end),
	bashorg_quote = with_data("bin/src/bashorg_quotes_unwrapped.tsv", function(quotes, ctx)
		return text.bashorg(quotes, ctx.rng)
	end),
	chuck = with_data("bin/data/chuck_norris.txt", function(jokes, ctx)
		return text.chuck(jokes, ctx.rng, ctx.sys.columns(ctx.env), ctx.sys.text_locale())
	end),
	mandelbash = function(ctx)
		return mandel.output(ctx.root .. "/bin/mandelbash", ctx.cache_dir, ctx.sys)
	end,
	asciidragon = function() return text.DRAGON end,
	just_one_taoup = with_data("bin/data/taoup.ansi", function(lines, ctx)
		return text.taoup(lines, ctx.rng)
	end),
	times_older_than_samson = function(ctx) return text.samson(ctx.now()) end,
	inthebeginning = function(ctx)
		local protocol, err = ctx.image_protocol()
		if not protocol then return nil, err end
		if protocol == "kitty" then
			return with_data("bin/data/inthebeginning.png", image.kitty)(ctx)
		end
		return data(ctx, "bin/data/inthebeginning.six")
	end,
}

-- Every listed pick has a runner and every runner is listed, checked at load
-- so an omission fails on the first run rather than at a random startup.
local listed = {}
for _, pool in ipairs({ M.TEXT, M.IMAGE }) do
	for _, name in ipairs(pool) do
		assert(runners[name], "fun_intro: pick '" .. name .. "' has no runner")
		assert(not listed[name], "fun_intro: pick '" .. name .. "' is listed twice")
		listed[name] = true
	end
end
for name in pairs(runners) do
	assert(listed[name], "fun_intro: runner '" .. name .. "' is in no pool")
end

function M.known(name) return listed[name] == true end

-- The pool for this terminal: images only where the shell said it can show them.
function M.pool(image_capable)
	local pool = {}
	for _, name in ipairs(M.TEXT) do pool[#pool + 1] = name end
	if image_capable then
		for _, name in ipairs(M.IMAGE) do pool[#pool + 1] = name end
	end
	return pool
end

function M.run(name, ctx)
	local runner = runners[name]
	if not runner then return nil, "unknown pick '" .. tostring(name) .. "'" end
	return runner(ctx)
end

return M

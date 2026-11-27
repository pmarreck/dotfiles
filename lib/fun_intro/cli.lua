-- Command-line entry points: `fun_intro` itself and the standalone pick
-- commands (chuck, bashorg_quote, ...). Each returns an exit status.
local picks = require("fun_intro.picks")
local context = require("fun_intro.context")

local M = {}

local USAGE = [[
Usage: fun_intro [--pick=NAME | --test]

Print one random decoration, as interactive shells do at startup. Image picks
join the pool only when IMAGE_CAPABLE=true.

  --pick=NAME   Print one specific pick, regardless of the pool
  --test        Print every pick in the pool, in order
  -h, --help    Show this help
]]

local function emit(output)
	io.stdout:write(output)
	io.stdout:flush()
end

local function fail(prefix, message)
	io.stderr:write(prefix, message, "\n")
	return 1
end

function M.fun_intro(argv, root, ctx)
	local mode, forced = "random", nil
	for _, a in ipairs(argv) do
		if a == "-h" or a == "--help" then
			io.stdout:write(USAGE)
			return 0
		elseif a == "--test" then
			mode = "test"
		elseif a == "--pick-one" then
			mode = "random"
		elseif a:sub(1, 7) == "--pick=" then
			forced = a:sub(8)
		else
			io.stderr:write("fun_intro: unknown arg: ", a, "\n")
			return 2
		end
	end
	ctx = ctx or context.live(root)
	local pool = picks.pool(ctx.env("IMAGE_CAPABLE") == "true")

	if mode == "test" then
		local failures = 0
		for _, name in ipairs(pool) do
			io.stderr:write("Running '", name, "' from fun_intro:\n")
			local output, err = picks.run(name, ctx)
			if output then emit(output) else failures = failures + fail("fun_intro: " .. name .. ": ", err) end
			emit("\n")
		end
		return failures == 0 and 0 or 1
	end

	local name = forced
	if name then
		if not picks.known(name) then return fail("fun_intro --pick=" .. name .. ": ", "unknown pick") + 126 end
	else
		name = pool[ctx.rng.int(#pool)]
	end
	if (ctx.env("DEBUG_SHELLCONFIG") or "") ~= "" then emit("Running '" .. name .. "' from fun_intro\n") end
	local output, err = picks.run(name, ctx)
	if not output then return fail("fun_intro: " .. name .. ": ", err) end
	emit(output)
	return 0
end

-- A standalone pick command. `--test` runs its test file, as the Bash
-- versions did; any other arguments are ignored, as they were.
function M.pick_command(name, argv, root, ctx)
	if argv[1] == "--test" then
		local test_file = root .. "/bin/test/" .. name .. "_test"
		if not io.open(test_file, "rb") then return 0 end
		return os.execute("'" .. test_file:gsub("'", "'\\''") .. "' >/dev/null") == 0 and 0 or 1
	end
	ctx = ctx or context.live(root)
	local output, err = picks.run(name, ctx)
	if not output then return fail(name .. ": ", err) end
	emit(output)
	return 0
end

return M

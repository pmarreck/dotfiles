-- Test driver for the intro's pure LuaJIT modules. Each mode forces the random
-- choice the way the matching oracle in fun_intro_text_test forces it, and
-- prints what the module produced. Usage: drive.lua MODE ARGS...
local text = require("fun_intro.text")
local wrap = require("fun_intro.wrap")
local sys = require("fun_intro.sys")

local mode = arg[1]

local function read(path) return assert(sys.read(path), "cannot read " .. path) end

local function lines_of(path)
	local out = {}
	for line in io.lines(path) do out[#out + 1] = line end
	return out
end

if mode == "chuck" then
	-- chuck WIDTH DATA INDEX...: every record in order, as `cut | fold` prints
	-- the whole file, then the picks the random source chose at each INDEX.
	local width, data = tonumber(arg[2]), read(arg[3])
	local records = text.records(data)
	local locale = sys.text_locale()
	for _, record in ipairs(records) do io.write(text.chuck_format(record, width, locale)) end
	for k = 4, #arg do
		local index = tonumber(arg[k])
		io.write(text.chuck(data, { int = function(n) assert(n == #records) return index end }, width, locale))
	end
elseif mode == "fold" then
	-- fold WIDTHS_CSV FILE...: each file at each width, separated by "\0".
	local locale = sys.text_locale()
	for w in arg[2]:gmatch("%d+") do
		for k = 3, #arg do
			io.write(wrap.fold_spaces(read(arg[k]), tonumber(w), locale), "\0")
		end
	end
elseif mode == "bashorg" or mode == "taoup" then
	-- bashorg|taoup UNITS_FILE DATA: one pick per rand() value, "\0" after each.
	local data = read(arg[3])
	for _, line in ipairs(lines_of(arg[2])) do
		local u = tonumber(line)
		local rng = { unit = function() return u end }
		io.write(mode == "bashorg" and text.bashorg(data, rng) or text.taoup(data, rng), "\0")
	end
elseif mode == "warhammer" then
	-- warhammer DATA: the range requested, then the picks at both endpoints.
	local data = read(arg[2])
	local requested
	local function pick(choice)
		return text.warhammer(data, { int = function(n) requested = n; return choice(n) end })
	end
	local first = pick(function() return 1 end)
	local last = pick(function(n) return n end)
	io.write(requested, "\n", first, last)
elseif mode == "samson" then
	-- samson NOW...: the sentence at each clock reading.
	for k = 2, #arg do io.write(text.samson(tonumber(arg[k]))) end
elseif mode == "terminal" then
	-- terminal ROWS: kitty and sixel verdicts per row of
	-- TERM|TERM_PROGRAM|KITTY_WINDOW_ID|WSLENV|ALACRITTY_LOG|ALACRITTY_WINDOW_ID|SIXEL|PARENT
	local terminal = require("fun_intro.terminal")
	local names = { "TERM", "TERM_PROGRAM", "KITTY_WINDOW_ID", "WSLENV", "ALACRITTY_LOG", "ALACRITTY_WINDOW_ID" }
	for _, line in ipairs(lines_of(arg[2])) do
		local fields, values = {}, {}
		for field in (line .. "|"):gmatch("([^|]*)|") do fields[#fields + 1] = field end
		for k, name in ipairs(names) do values[name] = fields[k] end
		local function env(name) return values[name] end
		local function terminfo_text() return fields[7] == "1" and "xterm-test|sixel capable,\n" or "xterm-test|plain,\n" end
		local function parent_command() return fields[8] end
		local kc, km = terminal.kitty(env)
		local sc, sm = terminal.sixel(env, terminfo_text, parent_command)
		io.write(kc, "|", km, "|", sc, "|", sm, "\n")
	end
elseif mode == "terminfo" then
	-- terminfo DIR NAME...: 1 when the compiled entry mentions sixel, else 0.
	local terminfo = require("fun_intro.terminfo")
	local function env(name) return name == "TERMINFO" and arg[2] or nil end
	for k = 3, #arg do
		local entry = terminfo.entry(arg[k], env, sys.read)
		local visible = entry and terminfo.visible_text(entry)
		io.write(arg[k], " ", entry == nil and "missing" or (visible:find("sixel", 1, true) and "1" or "0"), "\n")
	end
elseif mode == "protocol" then
	-- protocol: image_protocol over env rows NAME=VALUE,... with no probes.
	local terminal = require("fun_intro.terminal")
	for _, line in ipairs(lines_of(arg[2])) do
		local values = {}
		for name, value in line:gmatch("([%w_]+)=([^,]*)") do values[name] = value end
		local protocol, err = terminal.image_protocol(function(name) return values[name] end,
			function() return values.TERMINFO_TEXT or "" end, function() return "" end)
		io.write(line, " => ", tostring(protocol), err and (" (" .. err .. ")") or "", "\n")
	end
elseif mode == "choose" then
	-- choose IMAGE_CAPABLE ROOT POOL_SIZE: the pick fun_intro makes for each
	-- value of the random source, with fortune and mandelbash stubbed.
	local cli = require("fun_intro.cli")
	local root, size = arg[3], tonumber(arg[4])
	local values = { DEBUG_SHELLCONFIG = "1", IMAGE_CAPABLE = arg[2] }
	local stub_sys = setmetatable({
		find_command = function() return "/stub/fortune" end,
		run = function(path) return "RAN " .. path .. "\n", 0 end,
		write_atomic = function() return true end,
		ensure_dir = function() return true end,
	}, { __index = sys })
	for k = 1, size do
		local chosen = false
		local ctx = {
			root = root, sys = stub_sys, now = function() return 1764200000 end, cache_dir = "/nonexistent",
			env = function(name) return values[name] end,
			-- The first draw picks from the pool; later draws belong to the pick.
			rng = {
				int = function(n)
					if chosen then return 1 end
					chosen = true
					assert(n == size, "pool size " .. n)
					return k
				end,
				unit = function() return 0.5 end,
			},
			image_protocol = function() return "sixel" end,
		}
		local status = cli.fun_intro({}, root, ctx)
		io.write("\nstatus=", status, "\n")
	end
elseif mode == "mandel" then
	-- mandel WORKDIR: memoization with a fake file system, then failure and
	-- unwritable-cache behavior with the real one.
	local mandel = require("fun_intro.mandel")
	local work = arg[2]
	local runs, files, script = 0, {}, "echo one"
	local fs = {
		read = function(path) if path == "SCRIPT" then return script end return files[path] end,
		ensure_dir = function() return true end,
		write_atomic = function(path, data) files[path] = data; return true end,
		run = function() runs = runs + 1; return "render " .. runs .. "\n", 0 end,
	}
	local first = mandel.output("SCRIPT", "C", fs)
	local again = mandel.output("SCRIPT", "C", fs)
	script = "echo two"
	local edited = mandel.output("SCRIPT", "C", fs)
	script = "echo three"
	fs.run = function() runs = runs + 1; return "partial", 3 end
	local failed, err = mandel.output("SCRIPT", "C", fs)
	local count = 0
	for _ in pairs(files) do count = count + 1 end
	io.write(first, again, edited, tostring(failed), " ", tostring(err), "\nruns=", runs, " files=", count, "\n")
	local bad, bad_err = mandel.output(work .. "/bad.sh", work .. "/bad-cache", sys)
	io.write("real failure: ", tostring(bad), " ", tostring(bad_err), "\n")
	io.write("unwritable cache: ", tostring(mandel.output(work .. "/ok.sh", "/dev/null/cache", sys)))
elseif mode == "dragon" then
	io.write(text.DRAGON)
else
	io.stderr:write("drive.lua: unknown mode ", tostring(mode), "\n")
	os.exit(2)
end

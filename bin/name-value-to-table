#!/usr/bin/env luajit
--[[
name-value-to-table-lua: Read lines like FOO=bar and emit a pretty table.
Supports -i/--input <file> (or - for stdin), -o/--output <file> (or - for stdout),
--help, --test, and optional --key-width <n> --val-width <n>.
]]

local function print_help()
	io.stdout:write([[Usage: name-value-to-table-lua [-i file] [-o file] [--key-width N] [--val-width N]

Options:
  -i, --input <file>    Input file (default: - for stdin)
  -o, --output <file>   Output file (default: - for stdout)
  --key-width <N>       Key column width (default: auto)
  --val-width <N>       Value column width (default: auto)
  --help                Show this help
  --test                Run tests
]])
end

local function is_valid_var(line)
	local key, val = line:match("^([^=]+)=(.*)$")
	if not key or not val then return false end
	-- Key must match ^[a-zA-Z_][a-zA-Z0-9_\?]*(%%)?$
	if not key:match("^[a-zA-Z_][a-zA-Z0-9_%%?]*$") then return false end
	-- If key ends with %% and value starts with (, skip (Bash function export)
	if key:match("%%%%$") and val:match("^%(") then return false end
	return true
end

local function parse_pairs(lines)
	local pairs = {}
	for _, line in ipairs(lines) do
		if is_valid_var(line) then
			local key, val = line:match("^([^=]+)=(.*)$")
			table.insert(pairs, {key = key, val = val})
		end
	end
	return pairs
end

local function max_widths(pairs)
	if #pairs == 0 then return 1, 1 end
	local k, v = 0, 0
	for _, p in ipairs(pairs) do
		k = math.max(k, #p.key)
		v = math.max(v, #p.val)
	end
	return k, v
end

local function truncate(str, maxlen)
	if #str > maxlen then
		return str:sub(1, maxlen-1) .. "…" -- Unicode ellipsis
	else
		return str
	end
end

-- LuaJIT string.format() only supports widths up to 99 for %s
local MAX_WIDTH = 99

local function clamp_width(w)
	w = tonumber(w) or 1
	if w < 1 then return 1
	elseif w > MAX_WIDTH then return MAX_WIDTH
	else return math.floor(w) end
end

local function table_output(pairs, keyw, valw, out)
	if #pairs == 0 then
		out:write("(No valid name=value pairs found.)\n")
		return
	end
	keyw = clamp_width(keyw)
	valw = clamp_width(valw)
	-- Debug: print widths if debug env var is set
	if os.getenv("NVTABLE_DEBUG") then
		io.stderr:write(string.format("[DEBUG] keyw=%d valw=%d\n", keyw, valw))
	end
	local fmt = string.format("%%-%ds | %%-%ds\n", keyw, valw)
	out:write(fmt:format("NAME", "VALUE"))
	out:write(string.rep("-", keyw) .. "-+-" .. string.rep("-", valw) .. "\n")
	for _, p in ipairs(pairs) do
		out:write(fmt:format(truncate(p.key, keyw), truncate(p.val, valw)))
	end
end

local function read_lines(input)
	local lines = {}
	for line in input:lines() do table.insert(lines, line) end
	return lines
end

local function run(input_path, output_path, keyw, valw)
	local input = input_path == "-" and io.stdin or assert(io.open(input_path, "r"))
	local output = output_path == "-" and io.stdout or assert(io.open(output_path, "w"))
	local lines = read_lines(input)
	if input ~= io.stdin then input:close() end
	local pairs = parse_pairs(lines)
	-- Sort pairs by key ascending
	table.sort(pairs, function(a, b) return a.key < b.key end)
	local maxk, maxv = max_widths(pairs)
	keyw = keyw and clamp_width(keyw) or clamp_width(maxk)
	valw = valw and clamp_width(valw) or clamp_width(maxv)
	table_output(pairs, keyw, valw, output)
	if output ~= io.stdout then output:close() end
end

local function run_tests()
	io.stdout:write("Running tests...\n")
	local testlines = {"FOO=bar", "BAZ=qux", "LONG_NAME=some_value", "INVALID LINE", "_Q=ok"}
	local pairs = parse_pairs(testlines)
	assert(#pairs == 4, "Should parse 4 valid pairs")
	assert(pairs[1].key == "FOO" and pairs[1].val == "bar", "First pair correct")
	assert(pairs[3].key == "LONG_NAME", "Long name parsed")
	local k, v = max_widths(pairs)
	assert(k == 9 and v == 10, "Max widths correct")
	assert(truncate("abcdefg", 5) == "abcd…", "Truncation correct")
	io.stdout:write("All tests passed.\n")
end

-- CLI argument parsing (case+shift style)
local args = {...}
local input_path, output_path = "-", "-"
local keyw, valw
local i = 1
while i <= #args do
	local arg = args[i]
	if arg == "-i" or arg == "--input" then
		i = i + 1; input_path = args[i]
	elseif arg == "-o" or arg == "--output" then
		i = i + 1; output_path = args[i]
	elseif arg == "--key-width" then
		i = i + 1; keyw = args[i]
	elseif arg == "--val-width" then
		i = i + 1; valw = args[i]
	elseif arg == "--help" then
		print_help()
		os.exit(0)
	elseif arg == "--test" then
		run_tests()
		os.exit(0)
	else
		io.stderr:write("Unknown argument: " .. tostring(arg) .. "\n")
		print_help()
		os.exit(1)
	end
	i = i + 1
end

run(input_path, output_path, keyw, valw)

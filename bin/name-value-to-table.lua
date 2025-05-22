local print_help
print_help = function()
	return print([[Usage: name-value-to-table [-i file] [-o file] [--key-width N] [--val-width N]
Options:
	-i, --input <file>    Input file (default: - for stdin)
	-o, --output <file>   Output file (default: - for stdout)
	--key-width <N>       Key column width (default: auto)
	--val-width <N>       Value column width (default: auto)
	--help                Show this help
	--test                Run tests
]])
end
local is_valid_var
is_valid_var = function(line)
	if not (type(line) == "string") then
		return false
	end
	local key, val = line:match("^([^=]+)=(.*)$")
	if not (key and val) then
		return false
	end
	if not (key:match("^[a-zA-Z_][a-zA-Z0-9_%?]*$")) then
		return false
	end
	if key:match("%%$") and val:match("^%(") then
		return false
	end
	return true
end
local parse_pairs
parse_pairs = function(lines)
	local result = { }
	for _index_0 = 1, #lines do
		local line = lines[_index_0]
		if is_valid_var(line) then
			local k, v = line:match("^([^=]+)=(.*)$")
			table.insert(result, {
				k = k,
				v = v
			})
		end
	end
	return result
end
local max_widths
max_widths = function(pairs)
	if #pairs == 0 then
		return 1, 1
	end
	local k, v = 0, 0
	for _index_0 = 1, #pairs do
		local p = pairs[_index_0]
		k = math.max(k, #p.k)
		v = math.max(v, #p.v)
	end
	return k, v
end
local truncate
truncate = function(str, maxlen)
	if #str > maxlen then
		return str:sub(1, maxlen - 1) .. "…"
	else
		return str
	end
end
local MAX_WIDTH = 99
local clamp_width
clamp_width = function(w)
	w = tonumber(w) or 1
	if w < 1 then
		return 1
	elseif w > MAX_WIDTH then
		return MAX_WIDTH
	else
		return math.floor(w)
	end
end
local table_output
table_output = function(pairs, keyw, valw, out)
	if #pairs == 0 then
		out:write("(No valid name=value pairs found.)\n")
		return 
	end
	keyw = clamp_width(keyw)
	valw = clamp_width(valw)
	if os.getenv("NVTABLE_DEBUG") then
		io.stderr:write("[DEBUG] keyw=" .. tostring(keyw) .. " valw=" .. tostring(valw) .. "\n")
	end
	local fmt = string.format("%%-" .. tostring(keyw) .. "s | %%-" .. tostring(valw) .. "s\n")
	out:write(fmt:format("KEY", "VALUE"))
	out:write(string.rep("-", keyw) .. "-+-" .. string.rep("-", valw) .. "\n")
	for _index_0 = 1, #pairs do
		local p = pairs[_index_0]
		out:write(fmt:format(truncate(p.k, keyw), truncate(p.v, valw)))
	end
end
local run
run = function(input_path, output_path, keyw, valw)
	local inp
	if input_path == "-" or not input_path then
		inp = io.stdin
	else
		inp = assert(io.open(input_path, "r"), "Cannot open input file")
	end
	local out
	if output_path == "-" or not output_path then
		out = io.stdout
	else
		out = assert(io.open(output_path, "w"), "Cannot open output file")
	end
	local lines
	do
		local _accum_0 = { }
		local _len_0 = 1
		for line in inp:lines() do
			_accum_0[_len_0] = line
			_len_0 = _len_0 + 1
		end
		lines = _accum_0
	end
	local pairs = parse_pairs(lines)
	table.sort(pairs, function(a, b)
		return a.k < b.k
	end)
	if not keyw or not valw then
		local keyw1, valw1 = max_widths(pairs)
		keyw = keyw or keyw1
		valw = valw or valw1
	end
	table_output(pairs, keyw, valw, out)
	if not (inp == io.stdin) then
		inp:close()
	end
	if not (out == io.stdout) then
		return out:close()
	end
end
local run_tests
run_tests = function()
	print("Running tests...")
	local testlines = {
		"FOO=bar",
		"BAZ=qux",
		"LONG_NAME=some_value",
		"INVALID LINE",
		"_Q=ok"
	}
	local pairs = parse_pairs(testlines)
	assert(#pairs == 4, "Should parse 4 valid pairs")
	assert(pairs[1].k == "FOO" and pairs[1].v == "bar", "First pair correct")
	assert(pairs[3].k == "LONG_NAME", "Long name parsed")
	local k, v = max_widths(pairs)
	assert(k == 9 and v == 10, "Max widths correct")
	assert(truncate("abcdefg", 5) == "abcd…", "Truncation correct")
	return print("All tests passed.")
end
local args = {
	...
}
local i = 1
local input_path, output_path, keyw, valw = "-", "-", nil, nil
while i <= #args do
	local arg = args[i]
	if arg == "-i" or arg == "--input" then
		i = i + 1
		input_path = args[i]
	elseif arg == "-o" or arg == "--output" then
		i = i + 1
		output_path = args[i]
	elseif arg == "--key-width" then
		i = i + 1
		keyw = args[i]
	elseif arg == "--val-width" then
		i = i + 1
		valw = args[i]
	elseif arg == "--help" then
		print_help()
		os.exit(0)
	elseif arg == "--test" then
		run_tests()
		os.exit(0)
	else
		io.stderr:write("Unknown argument: " .. tostring(tostring(arg)) .. "\n")
		print_help()
		os.exit(1)
	end
	i = i + 1
end
return run(input_path, output_path, keyw, valw)

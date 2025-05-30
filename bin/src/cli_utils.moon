#!/usr/bin/env moonrun
-- cli_utils.moon

ffi = require "ffi"
test_factory = require("test_factory").test_factory

ffi.cdef [[
	typedef long time_t;
	typedef struct timeval {
		time_t tv_sec;
		time_t tv_usec;
	} timeval;
	int gettimeofday(struct timeval* tv, void* tz);
]]

-- Better RNG seeding with microsecond precision
seed_rng = ->
	tv = ffi.new "timeval"
	ffi.C.gettimeofday tv, nil
	sec = tonumber tv.tv_sec
	usec = tonumber tv.tv_usec
	math.randomseed sec * 1e6 + usec
	math.random!

-- Argument parser
default_validator = -> true

parse_args = (config, argv = arg) ->
	options = {}
	positionals = {}
	helptext = {}

	spec_by_flag = {}
	for entry in *config
		for flag in *entry.flags
			spec_by_flag[flag] = entry
		if entry.description
			helptext[#helptext + 1] = table.concat(entry.flags, ", ") .. "\t" .. entry.description

	i = 1
	while i <= #argv
		token = argv[i]

		if token == "-h" or token == "--help"
			print "Usage:"
			for line in *helptext
				print "  ", line
			os.exit 0

		entry = spec_by_flag[token]
		if entry
			if entry.has_arg
				i += 1
				argval = argv[i]
				unless argval
					io.stderr\write "Missing argument for #{token}\n"
					os.exit 1
				validator = entry.validator or default_validator
				unless validator argval
					io.stderr\write "Invalid argument for #{token}: #{argval}\n"
					os.exit 2
				options[entry.name] = argval
			else
				options[entry.name] = true
		else
			positionals[#positionals + 1] = token
		i += 1

	{options, positionals}

-- Example spec format
-- config = {
--   { name: "verbose", flags: {"-v", "--verbose"}, has_arg: false, description: "Enable verbose mode" }
--   { name: "file", flags: {"-f", "--file"}, has_arg: true, description: "Path to input file", validator: (f) -> f and f != "" and io.open(f) != nil }
-- }

return {
	seed_rng: seed_rng
	assert_factory: test_factory
	parse_args: parse_args
}

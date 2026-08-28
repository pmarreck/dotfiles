local M = {}

local function positive_integer(text)
	if type(text) ~= "string" or not text:match("^[1-9]%d*$") then
		return nil
	end
	local value = tonumber(text)
	if not value or value > 9007199254740991 then
		return nil
	end
	return value
end

function M.parse_length(text)
	if not text then
		return 4, 14
	end

	local exact = positive_integer(text)
	if exact then
		return exact, exact
	end

	local minimum_text, maximum_text = text:match("^([1-9]%d*)%-([1-9]%d*)$")
	if not minimum_text then
		minimum_text, maximum_text = text:match("^([1-9]%d*)%.%.([1-9]%d*)$")
	end
	if not minimum_text then
		return nil, nil, "word length must be N, M-N, or M..N using positive integers"
	end

	local minimum = positive_integer(minimum_text)
	local maximum = positive_integer(maximum_text)
	if not minimum or not maximum then
		return nil, nil, "word length is outside the supported integer range"
	end
	if minimum > maximum then
		return nil, nil, "word-length range minimum must not exceed its maximum"
	end
	return minimum, maximum
end

function M.parse_args(arguments)
	local options = {
		no_proper_nouns = false,
		variant = nil,
	}
	local positionals = {}
	local options_enabled = true

	for _, argument in ipairs(arguments) do
		if options_enabled and argument == "--" then
			options_enabled = false
		elseif options_enabled and (argument == "-h" or argument == "--help") then
			options.mode = "help"
		elseif options_enabled and argument == "--about" then
			options.mode = "about"
		elseif options_enabled and argument == "--no-proper-nouns" then
			options.no_proper_nouns = true
		elseif options_enabled and argument == "--american" then
			options.variant = "american"
		elseif options_enabled and argument == "--british" then
			options.variant = "british"
		elseif options_enabled and argument:sub(1, 1) == "-" then
			return nil, string.format("unknown option: %s", argument)
		else
			positionals[#positionals + 1] = argument
		end
	end

	if options.mode then
		if #arguments ~= 1 then
			return nil, string.format("--%s does not accept other arguments", options.mode)
		end
		return options
	end

	if #positionals < 1 or #positionals > 2 then
		return nil, "expected NUM_WORDS and at most one WORD_LENGTH"
	end
	local count = positive_integer(positionals[1])
	if not count then
		return nil, "NUM_WORDS must be a positive integer"
	end
	local minimum, maximum, length_error = M.parse_length(positionals[2])
	if not minimum then
		return nil, length_error
	end

	options.count = count
	options.minimum = minimum
	options.maximum = maximum
	return options
end

function M.variant_for_locale(locale_name)
	if not locale_name then
		return "british"
	end
	local normalized = locale_name:lower()
	if normalized == "c" or normalized == "posix"
		or normalized:match("^c[%.@]") then
		return "british"
	end
	if normalized:match("[_%-]us$") or normalized:match("[_%-]us[%.@_%-]")
		or normalized:match("united[%s_%-]*states") then
		return "american"
	end
	return "british"
end

function M.filter_dictionary(file, minimum, maximum, no_proper_nouns, utf8_text)
	local pool = {}
	local seen = {}
	local line_number = 0

	for line in file:lines() do
		line_number = line_number + 1
		line = line:gsub("\r$", "")
		if line ~= "" and not seen[line] then
			local characters, utf8_error = utf8_text.codepoints(line)
			if not characters then
				return nil, string.format("dictionary line %d contains %s", line_number, utf8_error)
			end
			local usable = not utf8_text.has_whitespace(characters)
				and #characters >= minimum and #characters <= maximum
				and not (no_proper_nouns and line:match("^[A-Z][a-z]"))
			if usable then
				seen[line] = true
				pool[#pool + 1] = line
			end
		end
	end

	return pool
end

function M.integer_power(base, exponent)
	local digits = {1}
	for _ = 1, exponent do
		local carry = 0
		for index = 1, #digits do
			local product = digits[index] * base + carry
			digits[index] = product % 10
			carry = math.floor(product / 10)
		end
		while carry > 0 do
			digits[#digits + 1] = carry % 10
			carry = math.floor(carry / 10)
		end
	end

	local output = {}
	for index = #digits, 1, -1 do
		output[#output + 1] = string.char(48 + digits[index])
	end
	return table.concat(output)
end

function M.group_integer(digits)
	local first_group = #digits % 3
	if first_group == 0 then
		first_group = 3
	end
	local groups = {digits:sub(1, first_group)}
	for index = first_group + 1, #digits, 3 do
		groups[#groups + 1] = digits:sub(index, index + 2)
	end
	return table.concat(groups, ",")
end

return M

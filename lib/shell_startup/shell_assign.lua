-- Render variable assignments that Bash can eval without risk. Names must be
-- plain identifiers, and every value is single-quoted with each embedded
-- quote written as '\''. Inside single quotes Bash interprets nothing, so the
-- evaluated value is byte-for-byte the input, including spaces, globs, $,
-- backticks, backslashes, and newlines. NUL cannot occur in a shell variable.
local M = {}

function M.valid_name(name)
	return type(name) == "string" and name:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

function M.quote(value)
	return "'" .. (value:gsub("'", "'\\''")) .. "'"
end

function M.assignment(name, value)
	if not M.valid_name(name) then
		error("shell_assign: invalid variable name: " .. tostring(name), 2)
	end
	if type(value) ~= "string" then
		error("shell_assign: value for " .. name .. " must be a string", 2)
	end
	if value:find("\0", 1, true) then
		error("shell_assign: value for " .. name .. " contains NUL", 2)
	end
	return name .. "=" .. M.quote(value)
end

-- One assignment per line, in the given order: { {name, value}, ... }.
function M.render(pairs_list)
	local lines = {}
	for i, pair in ipairs(pairs_list) do lines[i] = M.assignment(pair[1], pair[2]) end
	return table.concat(lines, "\n") .. "\n"
end

return M

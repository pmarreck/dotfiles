-- truthy.lua
-- Lightweight truthiness helper for Lua scripts (mirrors shell truthy semantics)
--
-- Rules:
--   nil / empty string => false
--   Numeric 0 => false, any other number => true
--   Strings (case-insensitive) treated as false: "0", "false", "f", "no", "n", "off", "disable", "disabled", "none"
--   Everything else => true

local function truthy(val)
	if val == nil then
		return false
	end

	-- Keep booleans as-is
	if type(val) == "boolean" then
		return val
	end

	if type(val) == "number" then
		return val ~= 0
	end

	if type(val) ~= "string" then
		-- Any non-string, non-number value: fallback to true
		return true
	end

	if val == "" then
		return false
	end

	local lower = string.lower(val)
	if lower == "0" or lower == "false" or lower == "f"
		or lower == "no" or lower == "n" or lower == "off"
		or lower == "disable" or lower == "disabled"
		or lower == "none"
	then
		return false
	end

	return true
end

return {
	truthy = truthy,
}

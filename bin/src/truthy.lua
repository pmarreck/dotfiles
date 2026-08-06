-- truthy.lua
-- Lightweight truthiness helper for Lua scripts. String inputs mirror the
-- shell truthy/falsey presence-flag contract.
--
-- Rules:
--   nil => false (analogous to an unset shell variable)
--   Empty string => true (set without a payload is still set)
--   Numeric 0 => false, any other number => true
--   Strings (case-insensitive) treated as false: "0", "false", "f", "no", "n", "off", "disable", "disabled"
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

	local lower = string.lower(val)
	if lower == "0" or lower == "false" or lower == "f"
		or lower == "no" or lower == "n" or lower == "off"
		or lower == "disable" or lower == "disabled"
	then
		return false
	end

	return true
end

return {
	truthy = truthy,
}

local cjson = require("cjson")

local M = {}

local preferred_keys = {
	"schema", "subject", "description", "sender", "recipient", "datetime",
	"message_type", "response_expected", "priority", "tags", "reply_to",
}

local preferred_rank = {}
for index, key in ipairs(preferred_keys) do preferred_rank[key] = index end

--- Extract initial JSON frontmatter or opaque legacy frontmatter while
--- excluding every Markdown body byte after the closing delimiter.
function M.extract(text)
	text = tostring(text or "")
	if text:sub(1, 3) == "\239\187\191" then text = text:sub(4) end
	text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

	local lines = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
	local opening = lines[1]
	if opening ~= "---json" and opening ~= "---" then
		return nil, nil, "missing opening frontmatter delimiter", 3
	end

	local closing
	for index = 2, #lines do
		if lines[index] == "---" or lines[index] == "..." then
			closing = index
			break
		end
	end
	if not closing then return nil, nil, "unterminated frontmatter", 65 end

	local block = table.concat(lines, "\n", 2, closing - 1)
	if opening == "---" then return block, "legacy-text" end
	if not block:match("^%s*{") then
		return nil, nil, "invalid JSON: frontmatter must be one object", 65
	end
	local ok, decoded = pcall(cjson.decode, block)
	if not ok then return nil, nil, "invalid JSON: " .. tostring(decoded), 65 end
	return decoded, "json"
end

local function is_array(value)
	if type(value) ~= "table" then return false end
	local count, maximum = 0, 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
		count = count + 1
		if key > maximum then maximum = key end
	end
	return count > 0 and count == maximum
end

local function ordered_entries(value)
	local entries = {}
	for key, item in pairs(value) do
		entries[#entries + 1] = { label = tostring(key), value = item }
	end
	table.sort(entries, function(left, right)
		local left_rank = preferred_rank[left.label] or math.huge
		local right_rank = preferred_rank[right.label] or math.huge
		if left_rank ~= right_rank then return left_rank < right_rank end
		return left.label < right.label
	end)
	return entries
end

local function scalar(value)
	if value == cjson.null then return "null" end
	if type(value) == "boolean" then return value and "true" or "false" end
	if type(value) == "number" then return tostring(value) end
	return tostring(value)
end

local function compact_value(value)
	if type(value) ~= "table" then return scalar(value) end
	if is_array(value) then
		local values = {}
		for _, item in ipairs(value) do
			if type(item) == "table" then return cjson.encode(value) end
			values[#values + 1] = scalar(item)
		end
		return table.concat(values, ", ")
	end
	return cjson.encode(value)
end

local function render_json_frontmatter(value)
	local lines = {}
	if type(value) ~= "table" then return compact_value(value) end
	for _, entry in ipairs(ordered_entries(value)) do
		lines[#lines + 1] = entry.label .. ": " .. compact_value(entry.value)
	end
	return table.concat(lines, "\n")
end

--- Render documents without consulting terminal state. Structured scalar
--- arrays become compact comma-separated values; legacy blocks remain opaque.
function M.render(documents)
	local lines = {}
	for index, document in ipairs(documents) do
		if index > 1 then lines[#lines + 1] = "" end
		if #documents > 1 then
			lines[#lines + 1] = "== " .. document.path .. " =="
		end
		if document.format == "json" then
			lines[#lines + 1] = render_json_frontmatter(document.frontmatter)
		else
			lines[#lines + 1] = document.frontmatter
		end
	end
	return table.concat(lines, "\n") .. "\n"
end

local function markdown_escape(value)
	return tostring(value):gsub("\\", "\\\\"):gsub("|", "\\|"):gsub("\n", "<br>")
end

--- Produce renderer-neutral Markdown; the CLI may send it to glow or bat, while
--- tests can inspect the table without terminal width or styling dependencies.
function M.render_markdown(documents)
	local lines = {}
	for index, document in ipairs(documents) do
		if index > 1 then lines[#lines + 1] = "" end
		lines[#lines + 1] = "## Frontmatter"
		lines[#lines + 1] = ""
		lines[#lines + 1] = "`" .. document.path:gsub("`", "\\`") .. "`"
		lines[#lines + 1] = ""
		if document.format == "json" and type(document.frontmatter) == "table" then
			lines[#lines + 1] = "| Field | Value |"
			lines[#lines + 1] = "| --- | --- |"
			for _, entry in ipairs(ordered_entries(document.frontmatter)) do
				lines[#lines + 1] = "| " .. markdown_escape(entry.label) .. " | "
					.. markdown_escape(compact_value(entry.value)) .. " |"
			end
		else
			lines[#lines + 1] = "```text"
			lines[#lines + 1] = document.frontmatter
			lines[#lines + 1] = "```"
		end
	end
	return table.concat(lines, "\n") .. "\n"
end

--- Encode all inputs under one invariant envelope, preventing callers from
--- branching on the number of supplied documents.
function M.render_json(documents)
	local ok, encoded = pcall(cjson.encode, { documents = documents })
	if not ok then return nil, "frontmatter is not JSON-compatible: " .. tostring(encoded) end
	return encoded .. "\n"
end

return M

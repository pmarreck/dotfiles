-- Offline regeneration from the pinned VarCon source; never called by a hook.
-- Usage: luajit generate-american-english-dictionary.lua varcon.txt > dictionary.tsv
local source = assert(arg[1], "VarCon input path required")
local candidates, american = {}, {}
local eligible = false
for line in io.lines(source) do
	if line:match("^# ") then
		local level = tonumber(line:match("%(level (%d+)%)"))
		eligible = line:find("<verified>", 1, true) ~= nil and level ~= nil and level <= 70
	elseif not line:match("^#") and line:find(": ", 1, true) then
		local data = line:match("^(.-) | ") or line
		data = data:match("^(.-) #") or data
		local preferred, british = nil, {}
		for entry in (data .. " / "):gmatch("(.-) / ") do
			local tags, word = entry:match("^%s*(.-): ([a-z]+)$")
			if tags then
				for tag in tags:gmatch("%S+") do
					if tag == "A" or tag == "A." then american[word] = true end
					if tag == "A" then preferred = word end
					if tag == "B" or tag == "B." then british[#british + 1] = word end
				end
			end
		end
		if eligible and preferred and not line:find("(-)", 1, true) then
			for _, word in ipairs(british) do
				if word ~= preferred then
					candidates[word] = candidates[word] or {}
					candidates[word][preferred] = true
				end
			end
		end
	end
end
local words = {}
for word in pairs(candidates) do if not american[word] then words[#words + 1] = word end end
table.sort(words)
for _, word in ipairs(words) do
	local targets = {}
	for target in pairs(candidates[word]) do targets[#targets + 1] = target end
	table.sort(targets)
	io.write(word, "\t", table.concat(targets, "/"), "\n")
end

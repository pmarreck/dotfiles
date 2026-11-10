-- unicode_nfc: Unicode Normalization Form C (composed) for UTF-8 strings, in
-- pure LuaJIT with no C library. Implements UAX #15: full canonical
-- decomposition, canonical ordering by combining class, then canonical
-- composition (with algorithmic Hangul). Tables come from unicode_nfc_data.lua,
-- generated from the Unicode Character Database. Malformed UTF-8 is rejected
-- rather than repaired, so callers never rename a file to a guessed name.

local buffer = require("string.buffer")
local data = require("unicode_nfc_data")

local CCC, DECOMP = data.ccc, data.decomp
local COMPOSE = {}
for composite, pair in pairs(data.pairs) do
	local row = COMPOSE[pair[1]]
	if not row then
		row = {}
		COMPOSE[pair[1]] = row
	end
	row[pair[2]] = composite
end

local S_BASE, L_BASE, V_BASE, T_BASE = 0xAC00, 0x1100, 0x1161, 0x11A7
local L_COUNT, V_COUNT, T_COUNT = 19, 21, 28
local N_COUNT = V_COUNT * T_COUNT
local S_COUNT = L_COUNT * N_COUNT

local byte = string.byte

-- Strict UTF-8 decode into an array of code points; nil on any overlong form,
-- surrogate, value above U+10FFFF, or truncated/stray continuation byte.
local function decode(s)
	local cps, n, i, len = {}, 0, 1, #s
	while i <= len do
		local b = byte(s, i)
		local cp, extra, min
		if b < 0x80 then cp, extra, min = b, 0, 0
		elseif b >= 0xC2 and b <= 0xDF then cp, extra, min = b - 0xC0, 1, 0x80
		elseif b >= 0xE0 and b <= 0xEF then cp, extra, min = b - 0xE0, 2, 0x800
		elseif b >= 0xF0 and b <= 0xF4 then cp, extra, min = b - 0xF0, 3, 0x10000
		else return nil end
		if i + extra > len then return nil end
		for k = 1, extra do
			local c = byte(s, i + k)
			if c < 0x80 or c > 0xBF then return nil end
			cp = cp * 64 + (c - 0x80)
		end
		if cp < min or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF) then return nil end
		n = n + 1
		cps[n] = cp
		i = i + extra + 1
	end
	return cps
end

local function encode(cps)
	local buf = buffer.new(#cps * 3)
	for i = 1, #cps do
		local cp = cps[i]
		if cp < 0x80 then buf:put(string.char(cp))
		elseif cp < 0x800 then
			buf:put(string.char(0xC0 + bit.rshift(cp, 6), 0x80 + bit.band(cp, 0x3F)))
		elseif cp < 0x10000 then
			buf:put(string.char(0xE0 + bit.rshift(cp, 12), 0x80 + bit.band(bit.rshift(cp, 6), 0x3F),
				0x80 + bit.band(cp, 0x3F)))
		else
			buf:put(string.char(0xF0 + bit.rshift(cp, 18), 0x80 + bit.band(bit.rshift(cp, 12), 0x3F),
				0x80 + bit.band(bit.rshift(cp, 6), 0x3F), 0x80 + bit.band(cp, 0x3F)))
		end
	end
	return buf:tostring()
end

local function decompose(cps)
	local d, n = {}, 0
	for i = 1, #cps do
		local cp = cps[i]
		local s_index = cp - S_BASE
		if s_index >= 0 and s_index < S_COUNT then
			n = n + 1; d[n] = L_BASE + math.floor(s_index / N_COUNT)
			n = n + 1; d[n] = V_BASE + math.floor((s_index % N_COUNT) / T_COUNT)
			local t = s_index % T_COUNT
			if t > 0 then n = n + 1; d[n] = T_BASE + t end
		else
			local seq = DECOMP[cp]
			if seq then
				for k = 1, #seq do n = n + 1; d[n] = seq[k] end
			else
				n = n + 1; d[n] = cp
			end
		end
	end
	return d
end

-- Canonical ordering: stable insertion sort of each run of non-starters by
-- combining class. Starters (class 0) never move.
local function reorder(d)
	for i = 2, #d do
		local c = d[i]
		local cc = CCC[c]
		if cc then
			local j = i - 1
			while j >= 1 and (CCC[d[j]] or 0) > cc do
				d[j + 1] = d[j]
				j = j - 1
			end
			d[j + 1] = c
		end
	end
end

local function compose_pair(starter, c)
	local l_index = starter - L_BASE
	if l_index >= 0 and l_index < L_COUNT then
		local v_index = c - V_BASE
		if v_index >= 0 and v_index < V_COUNT then
			return S_BASE + (l_index * V_COUNT + v_index) * T_COUNT
		end
	end
	local s_index = starter - S_BASE
	if s_index >= 0 and s_index < S_COUNT and s_index % T_COUNT == 0 then
		local t_index = c - T_BASE
		if t_index > 0 and t_index < T_COUNT then return starter + t_index end
	end
	local row = COMPOSE[starter]
	return row and row[c]
end

-- Canonical composition: each character joins the last starter unless a
-- character in between is a starter or has a class >= its own (blocked).
local function compose(d)
	local out, n = {}, 0
	local starter_at, last_cc = nil, nil -- last_cc nil: nothing since the starter
	for i = 1, #d do
		local c = d[i]
		local cc = CCC[c] or 0
		local composite
		if starter_at and (last_cc == nil or last_cc < cc) then
			composite = compose_pair(out[starter_at], c)
		end
		if composite then
			out[starter_at] = composite
		else
			n = n + 1
			out[n] = c
			if cc == 0 then
				starter_at, last_cc = n, nil
			else
				last_cc = cc
			end
		end
	end
	return out
end

local M = { unicode_version = data.version }

-- Return the NFC form of a UTF-8 string, or nil, "invalid UTF-8".
function M.normalize(s)
	if not s:find("[\128-\255]") then return s end
	local cps = decode(s)
	if not cps then return nil, "invalid UTF-8" end
	local d = decompose(cps)
	reorder(d)
	return encode(compose(d))
end

-- True when s is valid UTF-8 already in NFC; nil, "invalid UTF-8" otherwise.
function M.is_nfc(s)
	local normalized, err = M.normalize(s)
	if not normalized then return nil, err end
	return normalized == s
end

return M

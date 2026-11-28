-- Pure PATH construction for shell startup. Filesystem facts and string
-- collation are injected, so every rule here is testable without a host.
--
-- The result is rebuilt from scratch on every call, which keeps re-sourcing
-- idempotent: PATH = foreign injections, then declared additions (last
-- declared first), then the pristine base, deduplicated and filtered.
--
-- docs/shell-startup-path.md explains why each rule exists: the incidents
-- behind foreign-entry preservation, the deny-list, the exclusions and the
-- platform bootstrap.
local M = {}

-- Platform directories a project may publish under bin/. Only the current
-- one is admitted; the others are foreign and stripped even when inherited.
M.PF_NAMES = { "macos-arm64", "linux-amd64", "linux-arm64", "mswin-amd64", "mswin-arm64" }

-- Projects whose bin/ must never join PATH. Auto-discovery suits live personal
-- tools, but a dormant project with generic command names would capture those
-- names machine-wide. mpnetwork's bin/ holds 2023-era deploy helpers named
-- yarn, mocha, s, scale, secret, predeps, dbup/dbdown, and version.bump; its
-- yarn was once the only yarn on PATH. Matched by exact project name.
M.CODE_BIN_DENYLIST = { "mpnetwork" }

-- Entries dropped by exact string match, mostly macOS cruft that keeps
-- reinserting itself. The first is the literal string with a tilde, as the
-- original declaration had it.
M.PATH_EXCLUSIONS = {
	"~/.dotnet/tools",
	"/usr/local/share/dotnet",
	"/System/Cryptexes/App/usr/bin",
	"/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin",
	"/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin",
	"/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin",
}

-- Declared additions in last-prepend-wins order: later entries end up closer
-- to the front of PATH. Nonexistent directories are dropped at the end.
function M.declared_additions(home, code, ostype)
	local additions = {
		-- User-local bins (XDG, pip --user, etc.)
		home .. "/.local/bin",
		home .. "/Scripts",
		home .. "/.cargo/bin",
		home .. "/.npm-global/bin",
		-- mise shims for Node only. Shims rather than `mise activate`, so
		-- non-interactive shells get node too and PATH never changes per
		-- directory. Kept behind the Nix entries so Nix wins collisions.
		home .. "/.local/share/mise/shims",
		home .. "/.local/share/pnpm/bin",
	}
	if ostype:sub(1, 6) == "darwin" then
		-- macOS Nix: prefer Nix over the system.
		additions[#additions + 1] = "/nix/var/nix/profiles/default/bin"
		additions[#additions + 1] = home .. "/.nix-profile/bin"
		additions[#additions + 1] = "/run/current-system/sw/bin"
	end
	for _, entry in ipairs({
		home .. "/bin",
		-- Vendor-installed AI agent CLIs. Their installers append a raw PATH
		-- export to .bashrc or .bash_profile, which would escape these ordering
		-- and dedup rules; declare them here instead. (The oMLX installer also
		-- replaced the ~/.bash_profile symlink with an edited copy.)
		home .. "/.antigravity/antigravity/bin",
		home .. "/.grok/bin",
		home .. "/.omlx/bin",
		-- Non-Zig personal projects
		code .. "/ixnay/bin",
		code .. "/jumpscript/bin",
		code .. "/yt-transcriber/bin",
		code .. "/printable_binary/bin",
		code .. "/rm_safe/bin",
	}) do
		additions[#additions + 1] = entry
	end
	return additions
end

-- Nonempty components of a colon-separated list, in order.
function M.split(list)
	local parts = {}
	for part in (list or ""):gmatch("[^:]+") do parts[#parts + 1] = part end
	return parts
end

local function set_of(list)
	local set = {}
	for _, item in ipairs(list) do set[item] = true end
	return set
end

local function starts_with(s, prefix) return s:sub(1, #prefix) == prefix end
local function ends_with(s, suffix) return #s >= #suffix and s:sub(-#suffix) == suffix end

-- Matches the shell pattern "$CODE"/*/SUFFIX, where * may span slashes.
local function under_code_with_suffix(path, code, suffix)
	return starts_with(path, code .. "/") and #path >= #code + 1 + #suffix and ends_with(path, suffix)
end

-- Discover project command directories under CODE. Returns the legacy build
-- output directories followed by generic bin/ directories and then current
-- bin/<PF> directories, all in Bash glob order (full paths under strcoll).
function M.discover(code, pf, fs, before)
	local denied = set_of(M.CODE_BIN_DENYLIST)
	local projects = {}
	for _, name in ipairs(fs.list_dir(code) or {}) do
		-- Bash's * skips dot names, and denial is by exact project name.
		if name:sub(1, 1) ~= "." and not denied[name] then projects[#projects + 1] = name end
	end

	local function matches(suffix)
		local found = {}
		for _, name in ipairs(projects) do
			local path = code .. "/" .. name .. suffix
			if fs.is_dir(path) then found[#found + 1] = { name = name, path = path } end
		end
		table.sort(found, function(a, b) return before(a.path, b.path) end)
		return found
	end

	local discovered = {}
	-- A project that publishes bin/<PF> has retired its raw build outputs.
	for _, suffix in ipairs({ "/result/bin", "/zig-out/bin" }) do
		for _, match in ipairs(matches(suffix)) do
			if not fs.is_dir(code .. "/" .. match.name .. "/bin/" .. pf) then
				discovered[#discovered + 1] = match.path
			end
		end
	end
	-- Generic bins first, then native PF bins, so after the last-prepend-wins
	-- rebuild every native directory precedes every generic one.
	local native = {}
	for _, match in ipairs(matches("/bin")) do
		discovered[#discovered + 1] = match.path
		if fs.is_dir(match.path .. "/" .. pf) then native[#native + 1] = match.path .. "/" .. pf end
	end
	for _, path in ipairs(native) do discovered[#discovered + 1] = path end
	return discovered
end

-- Whether a candidate entry is admissible, given the current PF.
local function admissible(path, code, pf, fs, excluded)
	if excluded[path] then return false end
	-- Denial is a property of the destination, not of how the entry arrived.
	for _, deny in ipairs(M.CODE_BIN_DENYLIST) do
		local root = code .. "/" .. deny
		if path == root or starts_with(path, root .. "/") then return false end
	end
	-- Retire raw outputs once a project publishes its current PF directory.
	for _, suffix in ipairs({ "/result/bin", "/zig-out/bin" }) do
		if under_code_with_suffix(path, code, suffix) then
			if fs.is_dir(path:sub(1, #path - #suffix) .. "/bin/" .. pf) then return false end
			break
		end
	end
	-- Admit only the current platform's bin/<PF> directories.
	for _, name in ipairs(M.PF_NAMES) do
		if under_code_with_suffix(path, code, "/bin/" .. name) then
			if name ~= pf then return false end
			break
		end
	end
	return fs.is_dir(path)
end

-- input: home, incoming (PATH at entry), orig_path (pristine base, already
-- captured by the caller), pf, ostype. Returns the new PATH string.
function M.build(input, fs, before)
	local home, pf, ostype = input.home, input.pf, input.ostype or ""
	local code = home .. "/Code"
	local additions = M.declared_additions(home, code, ostype)
	for _, path in ipairs(M.discover(code, pf, fs, before)) do additions[#additions + 1] = path end
	local base = M.split(input.orig_path)

	-- Foreign entries are injections from external tools (nix shell, nix
	-- develop, direnv): incoming PATH minus the base minus our additions.
	-- ORIG_PATH is inherited, so it predates those injections; rebuilding
	-- from it alone would delete them.
	local known = set_of(base)
	for _, path in ipairs(additions) do known[path] = true end
	local candidates = {}
	for _, path in ipairs(M.split(input.incoming)) do
		if not known[path] then
			candidates[#candidates + 1] = path
			known[path] = true
		end
	end
	for i = #additions, 1, -1 do candidates[#candidates + 1] = additions[i] end
	-- On macOS the Nix system profile is also the modern-Bash bootstrap, so it
	-- stays reachable. NixOS orders its own privileged wrappers ahead of it.
	if ostype:sub(1, 6) == "darwin" and fs.is_dir("/run/current-system/sw/bin") then
		candidates[#candidates + 1] = "/run/current-system/sw/bin"
	end
	for _, path in ipairs(base) do candidates[#candidates + 1] = path end

	local excluded = set_of(M.PATH_EXCLUSIONS)
	local seen, final = {}, {}
	for _, path in ipairs(candidates) do
		if not seen[path] then
			seen[path] = true
			if admissible(path, code, pf, fs, excluded) then final[#final + 1] = path end
		end
	end
	return table.concat(final, ":")
end

return M

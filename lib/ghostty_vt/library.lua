-- Locate and load libghostty-vt for the headless runner: the path the Nix
-- check exports in DOTFILES_LIBGHOSTTY_VT, or else the flake's pinned package,
-- built (or fetched from the binary cache) on first use.
local terminal = require("ghostty_vt.terminal")

local M = {}

-- `root` is the repository root holding flake.nix. Returns the loaded library
-- or nil and a message.
function M.ensure(root)
	local path = os.getenv("DOTFILES_LIBGHOSTTY_VT")
	if not path or path == "" then
		local pipe = io.popen("nix build --no-link --print-out-paths '" .. root:gsub("'", "'\\''")
			.. "#libghostty-vt' 2>/dev/null")
		local out = pipe and pipe:read("*a") or ""
		if pipe then pipe:close() end
		out = out:gsub("%s+$", "")
		if out == "" then return nil, "libghostty-vt is unavailable: nix build " .. root .. "#libghostty-vt failed" end
		path = out .. "/lib/libghostty-vt" .. (jit.os == "OSX" and ".dylib" or ".so")
	end
	local ok, lib = pcall(terminal.load, path)
	if not ok then return nil, tostring(lib) end
	return lib
end

return M

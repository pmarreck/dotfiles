-- Entry point for .pathconfig: compute shell environment facts and print Bash
-- assignments for the caller to eval. Inputs arrive in the environment because
-- .pathconfig passes its own shell state explicitly: HOME, PATH (as found on
-- entry), ORIG_PATH, OS, PF, OSTYPE, and the locale variables that decide glob
-- collation. Prints nothing and exits nonzero on any failure, so the caller
-- never evaluates a partial result.
--
-- Output, in order: PATH; then on Linux DISTRO, DISTRO_PRETTY, DISTRO_VERSION.
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
package.path = here .. "/?.lua;" .. package.path

local function fail(message)
	io.stderr:write("shell_startup: ", message, "\n")
	os.exit(1)
end

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	return text
end

local ok, result = pcall(function()
	local fs = require("posix_fs")
	local path_plan = require("path_plan")
	local os_release = require("os_release")
	local shell_assign = require("shell_assign")

	local home, pf, os_name = os.getenv("HOME"), os.getenv("PF"), os.getenv("OS")
	if not home or home == "" then error("HOME is not set", 0) end
	if not pf or pf == "" then error("PF is not set", 0) end
	local incoming = os.getenv("PATH") or ""
	local orig_path = os.getenv("ORIG_PATH")
	if not orig_path or orig_path == "" then orig_path = incoming end

	local assignments = {
		{ "PATH", path_plan.build({
			home = home,
			incoming = incoming,
			orig_path = orig_path,
			pf = pf,
			ostype = os.getenv("OSTYPE") or "",
		}, fs, fs.environment_collation()) },
	}
	-- A missing os-release yields empty facts, as the distro commands' captured
	-- output was empty; their "Unknown" stderr notice is not reproduced.
	if os_name == "linux" then
		local facts = os_release.facts(read_file("/etc/os-release") or "")
		for _, name in ipairs({ "DISTRO", "DISTRO_PRETTY", "DISTRO_VERSION" }) do
			assignments[#assignments + 1] = { name, facts[name] }
		end
	end
	return shell_assign.render(assignments)
end)
if not ok then fail(tostring(result)) end
io.stdout:write(result)

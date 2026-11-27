-- Entry point for .pathconfig: compute PATH and print Bash assignments for the
-- caller to eval. Inputs arrive in the environment because .pathconfig passes
-- its own shell state explicitly: HOME, PATH (as found on entry), ORIG_PATH,
-- PF, OSTYPE, and the locale variables that decide glob collation.
-- Prints nothing and exits nonzero on any failure, so the caller never
-- evaluates a partial result.
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
package.path = here .. "/?.lua;" .. package.path

local function fail(message)
	io.stderr:write("shell_startup: ", message, "\n")
	os.exit(1)
end

local ok, result = pcall(function()
	local fs = require("posix_fs")
	local path_plan = require("path_plan")
	local shell_assign = require("shell_assign")

	local home, pf = os.getenv("HOME"), os.getenv("PF")
	if not home or home == "" then error("HOME is not set", 0) end
	if not pf or pf == "" then error("PF is not set", 0) end
	local incoming = os.getenv("PATH") or ""
	local orig_path = os.getenv("ORIG_PATH")
	if not orig_path or orig_path == "" then orig_path = incoming end

	local path = path_plan.build({
		home = home,
		incoming = incoming,
		orig_path = orig_path,
		pf = pf,
		ostype = os.getenv("OSTYPE") or "",
	}, fs, fs.environment_collation())
	return shell_assign.render({ { "PATH", path } })
end)
if not ok then fail(tostring(result)) end
io.stdout:write(result)

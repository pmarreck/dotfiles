-- Entry point for .pathconfig: compute shell environment facts and print Bash
-- assignments for the caller to eval. Inputs arrive in the environment because
-- .pathconfig passes its own shell state explicitly: HOME, PATH (as found on
-- entry), ORIG_PATH, OS, PF, OSTYPE, the locale variables that decide glob
-- collation, the terminal variables, and SHELL_STARTUP_PPID (the shell's
-- $PPID). Prints nothing and exits nonzero on any failure, so the caller
-- never evaluates a partial result.
--
-- Output, in order: PATH; then on Linux DISTRO, DISTRO_PRETTY, DISTRO_VERSION,
-- and on macOS the same three plus SHELL_STARTUP_MACOS_FACTS=1 when
-- SystemVersion.plist and the version-name table are readable (see
-- macos_release.lua);
-- then SHELL_STARTUP_PARENT_COMMAND (the parent's name, as `ps -o comm=`
-- reports it), SIXEL_ENV, SIXEL_CAPABLE, KITTY_CAPABLE, IMAGE_CAPABLE; then
-- whichever of SED, DATE, TAC, SHUF, STAT, TIMEOUT the environment lacks,
-- resolved on the incoming PATH (see gnu_tools.lua), and
-- SHELL_STARTUP_LOGIN_SED, the sed .bash_profile chooses on the new PATH;
-- then SHELL_STARTUP_TMPDIR, the resolved /tmp .envconfig uses as TMPDIR, and
-- SHELL_STARTUP_TTY, the terminal on stdin (the caller's own: command
-- substitution captures only stdout), which .envconfig uses as GPG_TTY;
-- then, when SHELL_STARTUP_HOOKS=1 (an interactive shell), the
-- SHELL_STARTUP_HOOK_<TOOL>_BIN and _INIT pairs bin/apply-hooks evaluates
-- instead of running direnv, mcfly, and starship (see hook_init.lua).
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
package.path = here .. "/?.lua;" .. here .. "/../?.lua;" .. package.path

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
	local graphics_env = require("graphics_env")
	local gnu_tools = require("gnu_tools")
	local hook_init = require("hook_init")
	local macos_release = require("macos_release")

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
	elseif os_name == "macos" then
		-- Unreadable inputs leave .bashrc to run sw_vers and the name script.
		local facts = macos_release.facts(read_file("/System/Library/CoreServices/SystemVersion.plist"),
			read_file(here .. "/../../bin/mac_os_version_number_to_name"))
		if facts then
			for _, name in ipairs({ "DISTRO", "DISTRO_PRETTY", "DISTRO_VERSION" }) do
				assignments[#assignments + 1] = { name, facts[name] }
			end
			assignments[#assignments + 1] = { "SHELL_STARTUP_MACOS_FACTS", "1" }
		end
	end
	local parent = graphics_env.process_command(os.getenv("SHELL_STARTUP_PPID"))
	assignments[#assignments + 1] = { "SHELL_STARTUP_PARENT_COMMAND", parent }
	local graphics = graphics_env.facts(os.getenv, read_file, function() return parent end)
	for _, name in ipairs(graphics_env.NAMES) do
		assignments[#assignments + 1] = { name, graphics[name] }
	end

	-- GNU tool paths. A failure here must not cost the shell its PATH, so it
	-- reports and leaves the variables unset.
	local tools_ok, tools_error = pcall(function()
		local cache_home = os.getenv("XDG_CACHE_HOME")
		if not cache_home or cache_home == "" then cache_home = home .. "/.cache" end
		local cache_path = cache_home .. "/dotfiles/gnu-tool-versions"
		local function first_version_line(candidate)
			local pipe = io.popen("'" .. candidate:gsub("'", "'\\''") .. "' --version 2>/dev/null")
			if not pipe then return "" end
			local line = pipe:read("*l") or ""
			pipe:close()
			return line
		end
		local probe, save = gnu_tools.cached_probe(fs, first_version_line, {
			read = function() return read_file(cache_path) end,
			write = function(text) fs.write_atomic(cache_path, text) end,
		})
		local tools, messages = gnu_tools.resolve(os.getenv, incoming, home, fs, probe)
		local login_sed = gnu_tools.first_gnu({ "gsed", "sed" }, assignments[1][2], fs, probe)
		tools[#tools + 1] = { "SHELL_STARTUP_LOGIN_SED", login_sed or "" }
		save()
		for _, message in ipairs(messages) do io.stderr:write(message, "\n") end
		for _, tool in ipairs(tools) do assignments[#assignments + 1] = tool end
	end)
	if not tools_ok then io.stderr:write("shell_startup: GNU tool lookup failed: ", tostring(tools_error), "\n") end
	local tmp = fs.realpath("/tmp")
	if tmp then assignments[#assignments + 1] = { "SHELL_STARTUP_TMPDIR", tmp } end
	local tty = fs.ttyname(0)
	if tty then assignments[#assignments + 1] = { "SHELL_STARTUP_TTY", tty } end
	-- Like the GNU tools, a hook cache failure leaves apply-hooks to run the
	-- tools itself rather than costing the shell its PATH.
	if os.getenv("SHELL_STARTUP_HOOKS") == "1" then
		local cache_home = os.getenv("XDG_CACHE_HOME")
		if not cache_home or cache_home == "" then cache_home = home .. "/.cache" end
		local hooks_ok, hooks = pcall(hook_init.resolve, assignments[1][2], cache_home .. "/dotfiles/hook-init", fs)
		if hooks_ok then
			for _, hook in ipairs(hooks) do assignments[#assignments + 1] = hook end
		else
			io.stderr:write("shell_startup: hook init cache failed: ", tostring(hooks), "\n")
		end
	end
	return shell_assign.render(assignments)
end)
if not ok then fail(tostring(result)) end
io.stdout:write(result)

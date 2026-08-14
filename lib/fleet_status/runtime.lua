local M = {}

function M.getenv(name)
	return os.getenv(name)
end

function M.now_epoch()
	return os.time()
end

function M.shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function M.trim(value)
	local trimmed = (value or ""):gsub("%s+$", "")
	return trimmed
end

--- Execute the shell/process adapter while preserving stdout and exit status
--- as separate values for collectors that degrade failures into unknown data.
function M.run_command(command)
	local marker = "__FLEET_STATUS_EXIT__"
	local wrapped = command
		.. " 2>/dev/null; fleet_status_exit=$?; printf '\\n"
		.. marker
		.. ":%s\\n' \"$fleet_status_exit\""
	local pipe = io.popen(wrapped, "r")
	if not pipe then return "", false end
	local output = pipe:read("*a") or ""
	pipe:close()
	local body, status = output:match("^(.*)\n" .. marker .. ":(%d+)\n$")
	if not status then return output, false end
	return body, tonumber(status) == 0
end

function M.run_git(repo, arguments)
	local git = os.getenv("FLEET_STATUS_GIT") or "git"
	return M.run_command("LC_ALL=C " .. M.shell_quote(git) .. " -C "
		.. M.shell_quote(repo) .. " " .. arguments)
end

function M.read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local contents = file:read("*a")
	file:close()
	return contents
end

--- Select the native stat binary and dialect without consulting host state.
function M.stat_spec(os_name, override)
	local stat = override
	if not stat or stat == "" then
		stat = os_name == "OSX" and "/usr/bin/stat" or "stat"
	end
	local format = os_name == "OSX" and "-f '%a %m'" or "-c '%X %Y'"
	return stat, format
end

--- Read access and modification epochs through the host's native stat dialect.
function M.file_times(path)
	local stat, format = M.stat_spec(jit.os, os.getenv("FLEET_STATUS_STAT"))
	local output, ok = M.run_command(
		M.shell_quote(stat) .. " " .. format .. " " .. M.shell_quote(path)
	)
	if not ok then return nil, nil end
	local atime, mtime = output:match("^(-?%d+)%s+(-?%d+)%s*$")
	if not atime then return nil, nil end
	return tonumber(atime), tonumber(mtime)
end

function M.write_file(path, contents)
	local file, open_err = io.open(path, "wb")
	if not file then return nil, tostring(open_err) end
	local write_ok, write_err = file:write(contents)
	local close_ok, close_err = file:close()
	if not write_ok or not close_ok then return nil, tostring(write_err or close_err) end
	return true
end

function M.remove_path(path)
	return os.remove(path)
end

--- Publish bytes through a same-directory temporary and atomic rename so
--- interrupted writers never expose a partial snapshot or provider record.
function M.write_atomic(path, contents)
	local directory = path:match("^(.*)/[^/]+$")
	if not directory then return nil, "state path has no directory: " .. path end
	local _, mkdir_ok = M.run_command("mkdir -p " .. M.shell_quote(directory))
	if not mkdir_ok then return nil, "cannot create state directory: " .. directory end
	local temp, temp_ok = M.run_command("mktemp " .. M.shell_quote(path .. ".tmp.XXXXXX"))
	temp = M.trim(temp)
	if not temp_ok or temp == "" then
		return nil, "cannot create temporary state file for: " .. path
	end

	local file, open_err = io.open(temp, "wb")
	if not file then
		os.remove(temp)
		return nil, tostring(open_err)
	end
	local write_ok, write_err = file:write(contents)
	local close_ok, close_err = file:close()
	if not write_ok or not close_ok then
		os.remove(temp)
		return nil, tostring(write_err or close_err)
	end
	local renamed, rename_err = os.rename(temp, path)
	if not renamed then
		os.remove(temp)
		return nil, tostring(rename_err)
	end
	return true
end

return M

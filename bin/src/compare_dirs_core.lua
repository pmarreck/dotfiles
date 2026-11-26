local M = {}

function M.compare_entries(path, left, right)
	local differences = {}

	local function add(field, left_value, right_value)
		differences[#differences + 1] = {
			path = path,
			field = field,
			val1 = left_value,
			val2 = right_value,
		}
	end

	if left.content_sha256 and right.content_sha256
		and left.content_sha256 ~= right.content_sha256 then
		add("content", left.content_sha256:sub(1, 16), right.content_sha256:sub(1, 16))
	end
	if left.size ~= right.size then
		add("size", tostring(left.size), tostring(right.size))
	end
	if left.mode ~= right.mode then
		add("mode", string.format("%04o", left.mode), string.format("%04o", right.mode))
	end
	if left.owner ~= right.owner then
		add("owner", left.owner, right.owner)
	end
	if left.group ~= right.group then
		add("group", left.group, right.group)
	end
	if left.mtime ~= right.mtime then
		add("mtime", os.date("%Y-%m-%d %H:%M:%S", left.mtime),
			os.date("%Y-%m-%d %H:%M:%S", right.mtime))
	end

	-- ctime records inode-status changes. Copying a tree necessarily changes it,
	-- and ordinary tools cannot preserve or set it, so it is not copy metadata.
	if left.symlink_target ~= right.symlink_target
		and (left.symlink_target or right.symlink_target) then
		add("symlink_target", left.symlink_target or "(none)",
			right.symlink_target or "(none)")
	end

	return differences
end

return M

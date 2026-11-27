-- A headless Ghostty terminal: libghostty-vt through the LuaJIT FFI. Bytes a
-- program writes go in with write(); replies the terminal owes the program
-- (device attributes, cursor reports, Kitty graphics acknowledgements) come out
-- of take_replies(); what a person would see comes out of text(), cursor(), and
-- placements().
local ffi = require("ffi")

local M = {}

local here = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local lib

local OPT_USERDATA, OPT_WRITE_PTY = 0, 1
local DATA_CURSOR_X, DATA_CURSOR_Y, DATA_KITTY_GRAPHICS = 3, 4, 30
local KITTY_PLACEMENT_ITERATOR = 1
local PLACEMENT_IMAGE_ID = 1
local IMAGE_WIDTH, IMAGE_HEIGHT = 3, 4
local SYS_OPT_DECODE_PNG = 1
local BUILD_INFO_VERSION_STRING = 5

-- The release ghostty_vt.h was checked against (see its header comment).
M.VERSION = "0.1.0-unstable-2026-07-20"

-- PNG payloads need a decoder. The runner checks where images land, not their
-- pixels, so this "decoder" returns a blank RGBA image of the size the PNG's
-- header declares. Kept alive for the process, as libghostty-vt holds it.
local decode_png
local function install_png_decoder()
	decode_png = ffi.cast("GhosttySysDecodePngFn", function(_, allocator, data, length, out)
		if length < 24 then return false end
		local function u32(at) return ((data[at] * 256 + data[at + 1]) * 256 + data[at + 2]) * 256 + data[at + 3] end
		local width, height = u32(16), u32(20)
		if width == 0 or height == 0 or width * height > 16777216 then return false end
		local size = width * height * 4
		local pixels = lib.ghostty_alloc(allocator, size)
		if pixels == nil then return false end
		ffi.fill(pixels, size, 0)
		out.width, out.height, out.data, out.data_len = width, height, pixels, size
		return true
	end)
	assert(lib.ghostty_sys_set(SYS_OPT_DECODE_PNG, decode_png) == 0, "ghostty_sys_set(DECODE_PNG) failed")
end

-- Load the shared library once, from `path` or DOTFILES_LIBGHOSTTY_VT.
function M.load(path)
	if lib then return lib end
	path = path or os.getenv("DOTFILES_LIBGHOSTTY_VT")
	assert(path and path ~= "", "set DOTFILES_LIBGHOSTTY_VT to libghostty-vt's shared library")
	local header = assert(io.open(here .. "/ghostty_vt.h", "rb"), "missing ghostty_vt.h")
	ffi.cdef(header:read("*a"))
	header:close()
	lib = ffi.load(path)
	local version = ffi.new("GhosttyString")
	assert(lib.ghostty_build_info(BUILD_INFO_VERSION_STRING, version) == 0, "ghostty_build_info failed")
	local found = ffi.string(version.ptr, version.len)
	assert(found:find(M.VERSION, 1, true), "libghostty-vt " .. found .. " is not the "
		.. M.VERSION .. " release ghostty_vt.h describes; recheck the declarations before using it")
	install_png_decoder()
	return lib
end

local Terminal = {}
Terminal.__index = Terminal

-- A terminal of `cols` x `rows` cells, each `cell_width` x `cell_height` pixels.
function M.new(cols, rows, cell_width, cell_height)
	M.load()
	local handle = ffi.new("GhosttyTerminal[1]")
	local options = ffi.new("GhosttyTerminalOptions", cols, rows, 10000)
	assert(lib.ghostty_terminal_new(nil, handle, options) == 0, "ghostty_terminal_new failed")
	local self = setmetatable({ handle = handle[0], replies = {}, cols = cols, rows = rows }, Terminal)
	self.reply_callback = ffi.cast("GhosttyTerminalWritePtyFn", function(_, _, data, length)
		self.replies[#self.replies + 1] = ffi.string(data, length)
	end)
	assert(lib.ghostty_terminal_set(self.handle, OPT_WRITE_PTY, self.reply_callback) == 0)
	assert(lib.ghostty_terminal_resize(self.handle, cols, rows, cell_width or 8, cell_height or 16) == 0)
	self.replies = {}
	local options = ffi.new("GhosttyFormatterTerminalOptions")
	options.size = ffi.sizeof(options)
	options.emit = 0 -- plain text
	options.trim = true
	options.unwrap = false
	options.extra.size = ffi.sizeof(options.extra)
	options.extra.screen.size = ffi.sizeof(options.extra.screen)
	local formatter = ffi.new("GhosttyFormatter[1]")
	assert(lib.ghostty_formatter_terminal_new(nil, formatter, self.handle, options) == 0)
	self.formatter = formatter[0]
	return self
end

function Terminal:write(bytes)
	if #bytes > 0 then lib.ghostty_terminal_vt_write(self.handle, ffi.cast("const uint8_t *", bytes), #bytes) end
end
-- vt_write and resize run the reply and PNG callbacks synchronously. LuaJIT
-- forbids entering a Lua callback from an FFI call made by compiled code, so
-- the functions making those calls stay interpreted.
jit.off(Terminal.write)
jit.off(M.new)

-- Bytes the terminal wants sent back to the program, in order.
function Terminal:take_replies()
	local replies = table.concat(self.replies)
	self.replies = {}
	return replies
end

-- The screen buffer, scrollback included, as plain text lines joined by "\n".
function Terminal:text()
	local pointer, length = ffi.new("uint8_t *[1]"), ffi.new("size_t[1]")
	assert(lib.ghostty_formatter_format_alloc(self.formatter, nil, pointer, length) == 0)
	local text = ffi.string(pointer[0], length[0])
	lib.ghostty_free(nil, pointer[0], length[0])
	return text
end

-- Zero-based cursor column and row within the active area.
function Terminal:cursor()
	local x, y = ffi.new("uint16_t[1]"), ffi.new("uint16_t[1]")
	lib.ghostty_terminal_get(self.handle, DATA_CURSOR_X, x)
	lib.ghostty_terminal_get(self.handle, DATA_CURSOR_Y, y)
	return x[0], y[0]
end

-- Every Kitty graphics placement: image id and pixel size, and the cells it
-- covers in the viewport.
function Terminal:placements()
	local graphics = ffi.new("GhosttyKittyGraphics[1]")
	if lib.ghostty_terminal_get(self.handle, DATA_KITTY_GRAPHICS, graphics) ~= 0 then return {} end
	local iterator = ffi.new("GhosttyKittyGraphicsPlacementIterator[1]")
	assert(lib.ghostty_kitty_graphics_placement_iterator_new(nil, iterator) == 0)
	local found = {}
	if lib.ghostty_kitty_graphics_get(graphics[0], KITTY_PLACEMENT_ITERATOR, iterator) == 0 then
		local id, width, height = ffi.new("uint32_t[1]"), ffi.new("uint32_t[1]"), ffi.new("uint32_t[1]")
		while lib.ghostty_kitty_graphics_placement_next(iterator[0]) do
			lib.ghostty_kitty_graphics_placement_get(iterator[0], PLACEMENT_IMAGE_ID, id)
			local image = lib.ghostty_kitty_graphics_image(graphics[0], id[0])
			lib.ghostty_kitty_graphics_image_get(image, IMAGE_WIDTH, width)
			lib.ghostty_kitty_graphics_image_get(image, IMAGE_HEIGHT, height)
			local info = ffi.new("GhosttyKittyGraphicsPlacementRenderInfo")
			info.size = ffi.sizeof(info)
			lib.ghostty_kitty_graphics_placement_render_info(iterator[0], image, self.handle, info)
			found[#found + 1] = {
				image_id = id[0], width = width[0], height = height[0],
				grid_cols = info.grid_cols, grid_rows = info.grid_rows,
				viewport_col = info.viewport_col, viewport_row = info.viewport_row,
				visible = info.viewport_visible,
			}
		end
	end
	lib.ghostty_kitty_graphics_placement_iterator_free(iterator[0])
	return found
end

function Terminal:free()
	if self.formatter then lib.ghostty_formatter_free(self.formatter); self.formatter = nil end
	if self.handle then lib.ghostty_terminal_free(self.handle); self.handle = nil end
	if self.reply_callback then self.reply_callback:free(); self.reply_callback = nil end
end

return M

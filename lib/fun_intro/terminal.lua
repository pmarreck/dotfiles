-- Terminal graphics capability, ported from the check_kitty_support and
-- check_sixel_support commands with their order, results, and messages:
-- 0 = supported, 1 = not supported, 2 = unknown. Inputs are injected: `env`
-- is a lookup function, and the terminfo text and parent process name are
-- fetched lazily only when a rule needs them.
local M = {}

local function set(value) return value ~= nil and value ~= "" end

-- Returns code, message (the DEBUG_SHELLCONFIG note).
function M.kitty(env)
	local term, program = env("TERM") or "", env("TERM_PROGRAM") or ""
	if term == "xterm-kitty" then return 0, "Kitty terminal detected via TERM." end
	if program == "WezTerm" then return 0, "WezTerm detected, which supports Kitty graphics protocol." end
	if program == "ghostty" then return 0, "Ghostty detected, which supports Kitty graphics protocol." end
	if set(env("KITTY_WINDOW_ID")) then return 0, "Kitty graphics protocol support detected via KITTY_WINDOW_ID." end
	if program == "Apple_Terminal" then return 1, "Apple Terminal does not support Kitty graphics protocol." end
	if set(env("ALACRITTY_LOG")) or set(env("ALACRITTY_WINDOW_ID")) then
		return 1, "Alacritty does not support Kitty graphics protocol."
	end
	if program == "WarpTerminal" then return 1, "Warp terminal does not support Kitty graphics protocol." end
	if program == "Hyper" then return 1, "Hyper does not support Kitty graphics protocol." end
	return 2, "Unable to determine Kitty graphics protocol support. TERM: " .. term .. ", TERM_PROGRAM: " .. program
end

-- Returns code, message, always_printed. The "unable to determine" message
-- went to stderr even without DEBUG_SHELLCONFIG, so always_printed is true.
function M.sixel(env, terminfo_text, parent_command)
	local term, program = env("TERM") or "", env("TERM_PROGRAM") or ""
	if (terminfo_text() or ""):find("sixel", 1, true) then return 0, "Sixel support detected via terminfo." end
	if program == "WezTerm" then return 0, "WezTerm detected, which supports Sixel." end
	if program == "Apple_Terminal" then return 1, "Apple Terminal detected, which does not support Sixel." end
	if set(env("WSLENV")) then return 2, "WSL detected. Sixel support depends on the Windows terminal used." end
	if set(env("ALACRITTY_LOG")) or set(env("ALACRITTY_WINDOW_ID")) then
		return 1, "Alacritty detected, which does not support Sixel as of 2024."
	end
	if term == "xterm-256color" and (parent_command() or ""):find("cool-retro-term", 1, true) then
		return 1, "cool-retro-term detected, which does not support Sixel."
	end
	if program == "WarpTerminal" then return 1, "Warp terminal detected, which does not support Sixel as of 2024." end
	if program == "Hyper" then
		return 1, "Hyper terminal detected, which does not support Sixel as of 2024,\tbut check again soon because sixel support was added to xterm.js, which Hyper uses."
	end
	if program == "ghostty" then
		return 1, "Ghostty terminal detected, which does not support Sixel (use Kitty graphics protocol instead)."
	end
	if term == "xterm-256color" or term == "xterm-kitty" or term == "mlterm" or term == "yaft" or term == "wezterm" then
		return 0, "Terminal (" .. term .. ") likely supports Sixel graphics."
	end
	return 2, "Unable to determine Sixel support. TERM: " .. term .. ", TERM_PROGRAM: " .. program, true
end

-- The image protocol to use, or nil and a message. DISPLAY_IMAGE_FORCE_PROTOCOL
-- wins, as in display_image. Next come the KITTY_CAPABLE and SIXEL_CAPABLE
-- facts the interactive shell exports, so a startup pick never probes twice.
-- Otherwise Kitty is preferred over Sixel, as display_image preferred it.
local NO_PROTOCOL = "No supported graphics protocol detected (tried kitty and sixel)."

function M.image_protocol(env, terminfo_text, parent_command)
	local forced = env("DISPLAY_IMAGE_FORCE_PROTOCOL")
	if forced and forced ~= "" then
		if forced == "kitty" or forced == "sixel" then return forced end
		return nil, "Unknown protocol '" .. forced .. "'. Use 'kitty' or 'sixel'."
	end
	local kitty, sixel = env("KITTY_CAPABLE"), env("SIXEL_CAPABLE")
	if kitty == "true" then return "kitty" end
	if sixel == "true" then return "sixel" end
	if kitty == "false" and sixel == "false" then return nil, NO_PROTOCOL end
	if M.kitty(env) == 0 then return "kitty" end
	if M.sixel(env, terminfo_text, parent_command) == 0 then return "sixel" end
	return nil, NO_PROTOCOL
end

return M

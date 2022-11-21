local wezterm = require 'wezterm';
-- see color schemes with examples at https://wezfurlong.org/wezterm/colorschemes/index.html
local scheme = wezterm.get_builtin_color_schemes()["Cobalt2"]
-- overrides
scheme.scrollbar_thumb = "#aaa"

return {
  check_for_updates = false,
  font = wezterm.font("Berkeley Mono"),
  harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' },
  color_schemes = {
    ["Cobalt Peter"] = scheme,
  },
  color_scheme = "Cobalt Peter",
  font_size = 12.0,
  window_background_opacity = 0.85,
  use_fancy_tab_bar = true,
  hide_tab_bar_if_only_one_tab = true,
  enable_scroll_bar = true,
  scrollback_lines = 1000000,
  -- https://wezfurlong.org/wezterm/config/lua/config/window_frame.html
  window_frame = {
    inactive_titlebar_bg = "#353535",
    active_titlebar_bg = "#2b2042",
    inactive_titlebar_fg = "#cccccc",
    active_titlebar_fg = "#ffffff",
    inactive_titlebar_border_bottom = "#2b2042",
    active_titlebar_border_bottom = "#2b2042",
    button_fg = "#cccccc",
    button_bg = "#2b2042",
    button_hover_fg = "#ffffff",
    button_hover_bg = "#3b3052",
  },
  -- https://wezfurlong.org/wezterm/config/lua/config/window_padding.html
  window_padding = {
    left = "1cell",
    right = "1.5cell",
    top = "0.5cell",
    bottom = "0.5cell",
  },
  -- https://wezfurlong.org/wezterm/config/lua/config/window_close_confirmation.html
  window_close_confirmation = "NeverPrompt",
  -- https://github.com/wez/wezterm/discussions/2426 plus modifications by me
  keys = {
    {
      key = 'c',
      mods = 'CTRL',
      action = wezterm.action_callback(function(window, pane)
        local sel = window:get_selection_text_for_pane(pane)
        if (not sel or sel == '') then
          window:perform_action(wezterm.action.SendKey{ key='c', mods='CTRL' }, pane)
        else
          window:perform_action(wezterm.action{ CopyTo = 'ClipboardAndPrimarySelection' }, pane)
        end
      end),
    },
    { key = 'v', mods = 'CTRL', action = wezterm.action.Paste },
    { key = 'v', mods = 'SHIFT|CTRL', action = wezterm.action_callback(function(window, pane)
      window:perform_action(wezterm.action.SendKey{ key='v', mods='CTRL' }, pane) end),
    },
    { key = 'V', mods = 'SHIFT|CTRL', action = wezterm.action_callback(function(window, pane)
      window:perform_action(wezterm.action.SendKey{ key='v', mods='CTRL' }, pane) end),
    },
    { key = 'c', mods = 'ALT', action = wezterm.action.Copy },
    { key = 'v', mods = 'ALT', action = wezterm.action.Paste },
  },
}

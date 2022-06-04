local wezterm = require 'wezterm';
-- see color schemes with examples at https://wezfurlong.org/wezterm/colorschemes/index.html
local scheme = wezterm.get_builtin_color_schemes()["Cobalt2"]
-- overrides
scheme.scrollbar_thumb = "#aaa"

return {
  font = wezterm.font("Berkeley Mono"),
  color_schemes = {
    ["Cobalt Peter"] = scheme,
  },
  color_scheme = "Cobalt Peter",
  font_size = 15.0,
  window_background_opacity = 0.85,
  use_fancy_tab_bar = false,
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
}

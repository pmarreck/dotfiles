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
  hide_tab_bar_if_only_one_tab = true,
  enable_scroll_bar = true,
  scrollback_lines = 1000000,
}

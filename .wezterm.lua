local wezterm = require 'wezterm';
return {
  font = wezterm.font("Berkeley Mono"),
  color_scheme = "Cobalt2",
  font_size = 15.0,
  window_background_opacity = 0.85,
  hide_tab_bar_if_only_one_tab = true,
  enable_scroll_bar = true,
  scrollback_lines = 1000000,
}

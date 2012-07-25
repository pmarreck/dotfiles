#!/usr/bin/env ruby

brew_bin = '/usr/local/bin/brew'

# output list of current taps to file
taps_str =  `#{brew_bin} tap`
taps = taps_str.split
File.open(File.expand_path("~/Tapfile"),'w'){|f| f.write taps_str}

# output list of current homebrews to file
brews_str = `#{brew_bin} list`
brews = brews_str.split
File.open(File.expand_path("~/Brewfile"),'w'){|f| f.write brews_str}

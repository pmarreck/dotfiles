#!/usr/bin/env ruby

# initialization
brew_bin = '/usr/local/bin/brew'

command_instructions = ''
command_instructions_array = []
install_taps = []
remove_taps = []
install_brews = []
remove_brews = []
update_homebrew = false
upgrade_brews = false

# compare live taps to file

expected_taps = File.read(File.expand_path("~/Tapfile")).split rescue []

current_taps = `#{brew_bin} tap`.split

new_taps = expected_taps - current_taps

removed_taps = current_taps - expected_taps

puts "** Possibly new taps **" unless new_taps.empty?
new_taps.each do |tap|
  print "Tap #{tap}? [Y/y] "
  y = gets[0,1].capitalize
  install_taps << tap unless y=='N'
end

puts "** Possibly removed taps **" unless removed_taps.empty?
removed_taps.each do |tap|
  print "Untap #{tap}? [Y/y] "
  y = gets[0,1].capitalize
  remove_taps << tap unless y=='N'
end

# compare live brews to file

expected_brews = File.read(File.expand_path("~/Brewfile")).split rescue []

current_brews = `#{brew_bin} list`.split

new_brews = expected_brews - current_brews

missing_brews = current_brews - expected_brews

puts "** Possibly new brews **" unless new_brews.empty?
new_brews.each do |brew|
  print "Install #{brew}? [Y/y] "
  y = gets[0,1].capitalize
  install_brews << brew unless y=='N'
end

puts "** Possibly removed brews **" unless missing_brews.empty?
missing_brews.each do |brew|
  print "Remove #{brew}? [N/n] "
  y = gets[0,1].capitalize
  remove_brews << brew if y=='Y'
end

print "Update Homebrew? [Y/y] "
u = gets[0,1].capitalize
update_homebrew = (u != 'N')

print "Upgrade brews? [N/n] "
u = gets[0,1].capitalize
upgrade_brews = (u == 'Y')

# build the command instructions
# tap
install_taps.each do |tap|
  command_instructions_array << "#{brew_bin} tap #{tap}"
end
# untap
remove_taps.each do |tap|
  command_instructions_array << "#{brew_bin} untap #{tap}"
end
# new brews
command_instructions_array << "#{brew_bin} install #{install_brews.join(' ')}" unless install_brews.empty?
# remove brews
command_instructions_array << "#{brew_bin} remove #{remove_brews.join(' ')}" unless remove_brews.empty?
# brew update
command_instructions_array << "#{brew_bin} update" if update_homebrew
# brew upgrade
command_instructions_array << "#{brew_bin} upgrade" if upgrade_brews

if command_instructions_array.empty?
  puts "Nothing to do."
else
  # ready...
  command_instructions = command_instructions_array.join('; ')
  # aim...
  puts "Running command: #{command_instructions}"
  # FIRE!
  exec(command_instructions)
end
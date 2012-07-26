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

# determine dependencies
graph = `#{brew_bin} graph`.split("\n")
graph_regex = /\s*"([^"]*)" -> "([^"]*)"/
depends_on_hash = {}
depended_on_by_hash = {}
graph.each do |dep_str|
  if dep=dep_str.match(graph_regex)
    depends_on_hash[dep[2]] ||= []
    depends_on_hash[dep[2]] << dep[1]
    depended_on_by_hash[dep[1]] ||= []
    depended_on_by_hash[dep[1]] << dep[2]
  end
end

# compare live taps to file, remove dependencies

expected_taps = File.read(File.expand_path("~/Tapfile")).split rescue []

current_taps = `#{brew_bin} tap`.split

new_taps = expected_taps - current_taps

removed_taps = current_taps - expected_taps


puts "** Kegs to potentially tap include: #{new_taps.join(', ')} **" unless new_taps.empty?
new_taps.each do |tap|
  print "Tap #{tap}? [Y/y] "
  y = gets[0,1].capitalize
  install_taps << tap unless y=='N'
end

puts "** Kegs to potentially untap include: #{removed_taps.join(', ')} **" unless removed_taps.empty?
removed_taps.each do |tap|
  print "Untap #{tap}? [N/n] "
  y = gets[0,1].capitalize
  remove_taps << tap if y=='Y'
end

# compare live brews to file

expected_brews = File.read(File.expand_path("~/Brewfile")).split rescue []
# expected_brews.dup.each{ |brew| expected_brews -= depends_on_hash[brew] if depends_on_hash[brew] }

current_brews = `#{brew_bin} list`.split
# current_brews.dup.each{ |brew| current_brews -= depends_on_hash[brew] if depends_on_hash[brew] }

new_brews = expected_brews - current_brews
new_brews.dup.each{ |brew| new_brews -= depends_on_hash[brew] if depends_on_hash[brew] }

inclusive_brews = expected_brews | current_brews

missing_brews = current_brews - expected_brews

puts "** Brews to potentially install include: #{new_brews.join(', ')} **" unless new_brews.empty?
new_brews.each do |brew|
  if depends_on_hash[brew]
    contextual_depends_on = depends_on_hash[brew] & inclusive_brews
    puts "#{brew} is dependent on #{contextual_depends_on.join(', ')}" unless contextual_depends_on.empty?
  end
  if depended_on_by_hash[brew]
    contextual_depended_on_by = depended_on_by_hash[brew] & inclusive_brews
    puts "#{contextual_depended_on_by.join(', ')} depends on #{brew}" unless contextual_depended_on_by.empty?
  end
  print "Install #{brew}? [Y/y] "
  y = gets[0,1].capitalize
  install_brews << brew unless y=='N'
end

puts "** Brews to potentially remove include: #{missing_brews.join(', ')} **" unless missing_brews.empty?
missing_brews.each do |brew|
  if depends_on_hash[brew]
    contextual_depends_on = depends_on_hash[brew] & inclusive_brews
    puts "#{brew} is dependent on #{contextual_depends_on.join(', ')}" unless contextual_depends_on.empty?
  end
  if depended_on_by_hash[brew]
    contextual_depended_on_by = depended_on_by_hash[brew] & inclusive_brews
    puts "#{contextual_depended_on_by.join(', ')} depends on #{brew}" unless contextual_depended_on_by.empty?
  end
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
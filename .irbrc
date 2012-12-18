
# Trace all requires
if ENV['trace_ruby_require']
  unless Kernel.respond_to? :require_with_sophistication
    module Kernel
      alias :require_without_sophistication :require
      def require_with_sophistication(*args)
        puts "+++ required #{args.join}"
        require_without_sophistication(*args)
      end
      alias :require :require_with_sophistication
    end
  end
end

#Load the readline module.
IRB.conf[:USE_READLINE] = true

#Remove the annoying irb(main):001:0 and replace with >>
IRB.conf[:PROMPT_MODE] = :SIMPLE

#Always nice to have auto indentation
IRB.conf[:AUTO_INDENT] = true

#History configuration
IRB.conf[:SAVE_HISTORY] = 1000
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-history"


#Load modules if not already loaded
IRB.conf[:LOAD_MODULES] = [] unless IRB.conf.key?(:LOAD_MODULES)

unless IRB.conf[:LOAD_MODULES].include?('irb/completion')
  IRB.conf[:LOAD_MODULES] << 'irb/completion' #Autocompletion of keywords
  IRB.conf[:LOAD_MODULES] << 'irb/ext/save-history' #Persist history across sessions
end

if ENV['RAILS_ENV']
  puts "IRB noticed you are in a Rails environment."
  load "#{ENV['HOME']}/.railsrc"
end

# # preloads
# %w[ ansi ].each do |lib|
# 	begin
# 		require lib
# 	rescue LoadError
# 		`gem install #{lib.gsub('/','_')}`
# 		require lib
# 	end
# end
# # usage: "string".ansi(:red)
# def _asa
#   require 'active_support/all'
# end

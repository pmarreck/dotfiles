#!/usr/bin/env ruby
# RPN calc in Ruby

class Rpn
  OPS = {
  	number:    ->(n)        { n.to_f           },
  	unary_op:  ->(op, n)    { n.send("#{op}@") },
    binary_op: ->(op, l, r) { l.send(op, r)    }
  }
  def initialize
    @stack = []
  end
  def stack_out
    puts @stack.map.with_index { |n, i| "#{i}: #{n}" }
  end

  def prompt
    print '>> '
  end

  def run
    loop do
      stack_out
      prompt
      line  = $stdin.gets.chomp
      case line
      when lambda(&:empty?)
        @stack << @stack.last
      when 'exit', 'x'
        stack_out
        break
      else
        type  = case line
                when /\A[-+*\/]\Z/ then :binary_op
                when /\An\Z/       then :unary_op
                else                    :number
                end
        op    = OPS[type]
        @stack << op[line.strip.tr('n', '-'), *@stack.pop(op.arity - 1)]
      end
    end
  end
end

Rpn.new.run

# frozen_string_literal: true

# Put this in a mixin for organization purposes.
module Maths
  def add
    mathop(:+)
  end

  def sub
    mathop(:-)
  end

  def mul
    mathop(:*)
  end

  def div
    mathop(:/)
  rescue ZeroDivisionError
    0
  end

  def and
    mathop(:&)
  end

  def or
    mathop(:|)
  end

  def xor
    mathop(:^)
  end
end

# Implements Forth operations over top a Ruby array.
class ForthStack < Array
  include Maths

  def initialize(*args)
    super(*args)
  end

  def cr
    puts ''
  end

  def dot
    op = pop
    print "#{op} " unless check_nil([op])
  end

  def drop
    pop
  end

  def dump
    print self
    puts ''
  end

  def dup
    op = pop
    insert(-1, op, op) unless check_nil([op])
  end

  def emit
    # print ASCII of the top of the stack
    op = pop
    print "#{op.to_s.codepoints[0]} " unless check_nil([op])
  end

  def equal
    op1 = pop
    op2 = pop
    (push op1 == op2 ? -1 : 0) unless check_nil([op1, op2])
  end

  def greater
    op1 = pop
    op2 = pop
    (push op2 < op1 ? -1 : 0) unless check_nil([op1, op2])
  end

  def invert
    push(~pop)
  end

  def lesser
    op1 = pop
    op2 = pop
    (push op2 < op1 ? -1 : 0) unless check_nil([op1, op2])
  end

  def over
    op1 = pop
    op2 = pop
    insert(-1, op2, op1) unless check_nil([op1, op2])
  end

  def rot
    op1 = pop
    op2 = pop
    op3 = pop
    insert(-1, op2, op1, op3) unless check_nil([op1, op2, op3])
  end

  def swap
    op1 = pop
    op2 = pop
    insert(-1, op1, op2) unless check_nil([op1, op2])
  end

  private

  def mathop(opr)
    op1 = pop
    op2 = pop
    push(op2.send(opr, op1)) unless check_nil([op1, op2])
  end

  # if any of the operands are nil, return true,
  # and put the ones that aren't back on the stack
  def check_nil(ops)
    ops.each do |op|
      next unless op.nil?

      warn 'Stack underflow'
      ops.reverse.each { |o| o.nil? ? nil : push(o) }
      return true
    end
    false
  end
end

# Holds a forth IF statement. Calling read_line will start parsing
# the IF statement starting with the line given. Reads into
# the true_block until an ELSE or THEN is found, then reads into
# the false_block until a THEN is found if an ELSE was found.
# If another IF is encountered, creates a new ForthIf class,
# and starts it parsing on the rest of the line, resuming it's
# own parsing where that IF left off.
class ForthIf
  def initialize
    @true_block = []
    @false_block = []
  end

  # NOTE: Does it need to parse loops? Two ways to do this:
  # 1 - Have the IF create LOOP objects when loops are found.
  # 2 - Completely ignore them, and have them be constructed
  # during evaluation of the IF block.

  def eval(stack)
    puts "True block: #{@true_block}"
    puts "False block: #{@false_block}"
    top = stack.pop
    return warn 'Stack underflow' if top.nil?
    return @false_block if top.zero?

    @true_block
  end

  def read_line(line)
    read_true(line)
  end

  private

  def read_true(line)
    read_true($stdin.gets.split) if line.empty?
    word = line.shift
    return [] if word.nil?

    word = word.downcase
    return line if word == 'then'
    return read_false(line) if word == 'else'

    read_true(add_to_block(@true_block, word, line))
  end

  def add_to_block(block, word, line)
    if word == 'if'
      new_if = ForthIf.new
      line = new_if.read_line(line)
      block << new_if
    else
      block << word
    end
    line
  end

  def read_false(line)
    puts 'reading true'
    read_true($stdin.gets.split) if line.empty?
    word = line.shift
    return [] if word.nil?

    word = word.downcase
    read_false(add_to_block(@false_block, word, line)) if word != 'then'
    line
  end
end

@stack = ForthStack.new
@user_words = {}
@keywords = %w[cr drop dump dup emit invert over rot swap]
@symbol_map = { '+' => 'add', '-' => 'sub', '*' => 'mul', '/' => 'div',
                '=' => 'equal', '.' => 'dot', '<' => 'lesser', '>' => 'greater' }

def interpret
  print '> '
  $stdin.each_line do |line|
    %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line.split)
    puts 'ok'
    print '> '
  end
end
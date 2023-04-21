# frozen_string_literal: true

SYNTAX =   '[SYNTAX]'
BAD_TYPE = '[BAD_TYPE]'
BAD_DEF =  '[BAD_DEF]'
BAD_WORD = '[BAD_WORD]'
BAD_LOOP = '[BAD_LOOP]'
STACK_UNDERFLOW = '[STACK_UNDERFLOW]'

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
    (push op2 > op1 ? -1 : 0) unless check_nil([op1, op2])
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

      warn "#{STACK_UNDERFLOW} #{ops}"
      ops.reverse.each { |o| o.nil? ? nil : push(o) }
      return true
    end
    false
  end
end

# Contains methods that are used by both ForthIf and ForthDo,
# and the future ForthBegin once it's implemented.
class ForthObj
  def initialize(bad_on_empty)
    @good = true
    @bad_on_empty = bad_on_empty
  end

  # this is quite nifty, if the word is if or do, it will be replaced with ForthIf or
  # ForthDo. This way, nested IF's and DO's can be supported, and can error check properly.
  # Waiting to build the new object until after parsing doesn't work, because the outermost IF
  # or DO will eat the closing word of the innermost IF or DO and fail.
  def add_to_block(block, word, line)
    begin
      new_word = Object.const_get("Forth#{word.capitalize}").new(@bad_on_empty)
      line = new_word.read_line(line)
      block << new_word
    # if the above fails, it's a normal word.
    rescue NameError
      block << word
    end
    line
  end

  private

  def read_until(line, block, end_word)
    if @bad_on_empty && line.empty?
      @good = false
      return []
    end
    return read_until($stdin.gets.split, block, end_word) if line.empty?

    word = line.shift
    return [] if word.nil?

    return line if word.downcase == end_word

    read_until(add_to_block(block, word, line), block, end_word)
  end
end

# Holds a forth IF statement. Calling read_line will start parsing
# the IF statement starting with the line given. Reads into
# the true_block until an ELSE or THEN is found, then reads into
# the false_block until a THEN is found if an ELSE was found.
# If another IF is encountered, creates a new ForthIf class,
# and starts it parsing on the rest of the line, resuming it's
# own parsing where that IF left off.
class ForthIf < ForthObj
  # takes in fail_on_empty, which tells the IF what to
  # do if it encounters an empty line. If it's true,
  # it sets @good to false. If it's false, it will keep
  # looking for more lines to read until it finds a THEN.
  def initialize(bad_on_empty)
    super(bad_on_empty)
    @true_block = []
    @false_block = []
  end

  def eval(stack)
    # If the IF is not good (there wasn't an ending THEN) warn and do nothing.
    return warn "#{SYNTAX} 'IF' without closing 'THEN'" unless @good

    top = stack.pop
    return warn STACK_UNDERFLOW if top.nil?
    return @false_block.dup if top.zero?

    @true_block.dup
  end

  def read_line(line)
    read_true(line)
  end

  private

  def read_true(line)
    # set @good to false if we're expecting a line and we get an empty line
    # If the IF being created is in a user defined word,
    # there should be a THEN statement before the end of the line.
    # If there isn't, the IF is not good, and since we are in
    # a user defined word, we should warn instead of trying to
    # read more lines from stdin.
    if @bad_on_empty && line.empty?
      @good = false
      return []
    end

    return read_true($stdin.gets.split) if line.empty?

    word = line.shift
    return [] if word.nil?

    return line if word.downcase == 'then'
    return read_until(line, @false_block, 'then') if word.downcase == 'else'

    read_true(add_to_block(@true_block, word, line))
  end
end

# Implements a DO loop. Reads into the block until a LOOP is found.
# On calling eval it pops two values off the stack: the start and end values
# for the loop. (End non-inclusive) From this it builds the sequence
# of blocks needed to execute the loop. For each iteration, it duplicates
# the base block, and replaces any I in the block with the current iteration value.
class ForthDo < ForthObj
  def initialize(bad_on_empty)
    super(bad_on_empty)
    @block = []
  end

  def read_line(line)
    read_until(line, @block, 'loop')
  end

  def eval(stack)
    return warn "#{SYNTAX} 'DO' without closing 'LOOP'" unless @good

    start = stack.pop
    limit = stack.pop
    return warn "#{STACK_UNDERFLOW} #{[start, limit]}" if start.nil? || limit.nil?
    return warn "#{BAD_LOOP} Invalid loop range" if start.negative? || limit.negative?
    return warn "#{BAD_LOOP} Invalid loop range" if start > limit

    do_loop(start, limit)
  end

  def do_loop(start, limit)
    block = []
    # for each interation, duplicate the block
    # one, and replace any I with the current loop iteration
    (start..limit - 1).each do |i|
      next_block = @block.dup.map { |w| w.is_a?(String) && w.downcase == 'i' ? i.to_s : w }
      block += next_block
    end
    block
  end
end

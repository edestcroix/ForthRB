# frozen_string_literal: true

SYNTAX =   '[SYNTAX]'
BAD_TYPE = '[BAD_TYPE]'
BAD_DEF =  '[BAD_DEF]'
BAD_WORD = '[BAD_WORD]'
BAD_LOOP = '[BAD_LOOP]'
BAD_ADDRESS = '[BAD_ADDRESS]'
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

  def greater
    op1 = pop
    op2 = pop
    (push op2 > op1 ? -1 : 0) unless check_nil([op1, op2])
  end

  def lesser
    op1 = pop
    op2 = pop
    (push op2 < op1 ? -1 : 0) unless check_nil([op1, op2])
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

# Implements a Heap for the ForthInterpreter to store variables in.
class ForthHeap
  def initialize
    @heap = []
    @name_map = {}
    @free = 0
  end

  def create(name)
    @free += 1
    @name_map[name] = @free + 1000 - 1
    @free + 1000 - 1
  end

  def allot(size)
    @free += size
  end

  def get_address(name)
    @name_map[name]
  end

  def defined?(name)
    @name_map.key?(name)
  end

  def set(addr, value)
    return warn "#{BAD_ADDRESS} #{addr}" if addr < 1000 || addr > 1000 + @free

    @heap[addr - 1000] = value
  end

  def get(address)
    return warn "#{BAD_ADDRESS} #{addr}" if address.nil?
    return warn "#{BAD_ADDRESS} #{address}" if address < 1000 || address > 1000 + @free

    @heap[address - 1000]
  end
end

class ForthObj
  attr_reader :remainder
end

class ForthWord < ForthObj
  def initialize(line, *)
    super()
    @remainder = line
  end

  private

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

# Forth CR operation
class ForthCr < ForthWord
  def eval(*)
    puts ''
  end
end

# Forth . operation
class ForthDot < ForthWord
  def eval(interpreter)
    op = interpreter.stack.pop
    print "#{op} " unless check_nil([op])
  end
end

# Forth Drop operation
class ForthDrop < ForthWord
  def eval(interpreter)
    interpreter.stack.pop
  end
end

# Forth Dump operation
class ForthDump < ForthWord
  def eval(interprer)
    print interprer.stack
    puts ''
  end
end

# Forth Dup operation
class ForthDup < ForthWord
  def eval(interpreter)
    interpreter.stack.push(interpreter.stack.last)
  end
end

# Forth Emit operation
class ForthEmit < ForthWord
  def eval(interpreter)
    # print ASCII of the top of the stack
    op = interpreter.stack.pop
    print "#{op.to_s[0].codepoints} " unless check_nil([op])
  end
end

# Forth Equal operation
class ForthEqual < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    (interpreter.stack.push op1 == op2 ? -1 : 0) unless check_nil([op1, op2])
  end
end

# Forth Greater operation
class ForthGreater < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    (interpreter.stack.push op2 > op1 ? -1 : 0) unless check_nil([op1, op2])
  end
end

# Forth Invert operation
class ForthInvert < ForthWord
  def eval(interpreter)
    interpreter.stack.push(~interpreter.stack.pop)
  end
end

# Forth Lesser operation
class ForthLesser < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    (interpreter.stack.push op2 < op1 ? -1 : 0) unless check_nil([op1, op2])
  end
end

# Forth Over operation
class ForthOver < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    interpreter.stack.insert(-1, op1, op2, op1) unless check_nil([op1, op2])
  end
end

# Forth Rot operation
class ForthRot < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    op3 = interpreter.stack.pop
    interpreter.stack.insert(-1, op2, op1, op3) unless check_nil([op1, op2, op3])
  end
end

# Forth Swap operation
class ForthSwap < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    interpreter.stack.insert(-1, op1, op2) unless check_nil([op1, op2])
  end
end

# Contains methods that are used by both ForthIf and ForthDo,
# and the future ForthBegin once it's implemented.
class ForthAdvObj < ForthObj
  def initialize(source, bad_on_empty, *)
    super()
    @source = source
    @good = true
    @bad_on_empty = bad_on_empty
  end

  def read_until(line, block, end_word)
    if @bad_on_empty && line.empty?
      @good = false
      return []
    end
    return read_until(@source.gets.split, block, end_word) if line.empty?

    word = line.shift
    return [] if word.nil?

    return line if word.downcase == end_word

    read_until(add_to_block(block, word, line), block, end_word)
  end

  private

  # adds words into a block of the class. If the word the beginning of an
  # IF, DO, or BEGIN it puts in the corresponding object instead.
  def add_to_block(block, word, line)
    begin
      new_word = Object.const_get("Forth#{word.capitalize}").new(line, @source, @bad_on_empty)
      line = new_word.remainder
      block << new_word
    # if the above fails, it's a normal word.
    rescue NameError
      block << word
    end
    line
  end
end

# Holds a forth IF statement. Calling read_line will start parsing
# the IF statement starting with the line given. Reads into
# the true_block until an ELSE or THEN is found, then reads into
# the false_block until a THEN is found if an ELSE was found.
# If another IF is encountered, creates a new ForthIf class,
# and starts it parsing on the rest of the line, resuming it's
# own parsing where that IF left off.
class ForthIf < ForthAdvObj
  # takes in fail_on_empty, which tells the IF what to
  # do if it encounters an empty line. If it's true,
  # it sets @good to false. If it's false, it will keep
  # looking for more lines to read until it finds a THEN.
  def initialize(line, source, bad_on_empty)
    super(source, bad_on_empty)
    @true_block = []
    @false_block = []
    @remainder = read_true(line)
  end

  def eval(interpreter)
    # If the IF is not good (there wasn't an ending THEN) warn and do nothing.
    return warn "#{SYNTAX} 'IF' without closing 'THEN'" unless @good

    top = interpreter.stack.pop
    return warn STACK_UNDERFLOW if top.nil?
    return interpreter.interpret_line(@false_block.dup, true) if top.zero?

    interpreter.interpret_line(@true_block.dup, true)
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

    return read_true(@source.gets.split) if line.empty?

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
class ForthDo < ForthAdvObj
  def initialize(line, source, bad_on_empty)
    super(source, bad_on_empty)
    @block = []
    @remainder = read_until(line, @block, 'loop')
  end

  def read_line(line)
    read_until(line, @block, 'loop')
  end

  def eval(interpreter)
    return warn "#{SYNTAX} 'DO' without closing 'LOOP'" unless @good

    start = interpreter.stack.pop
    limit = interpreter.stack.pop
    return warn "#{STACK_UNDERFLOW} #{[start, limit]}" if start.nil? || limit.nil?
    return warn "#{BAD_LOOP} Invalid loop range" if start.negative? || limit.negative?
    return warn "#{BAD_LOOP} Invalid loop range" if start > limit

    do_loop(interpreter, start, limit)
  end

  # for each iteration from start to limit, set I to the current value,
  # and interpret the block using the interprer
  def do_loop(interpreter, start, limit)
    (start..limit - 1).each do |i|
      run_block = @block.dup.map { |w| w.is_a?(String) && w.downcase == 'i' ? i.to_s : w }
      interpreter.interpret_line(run_block, true)
    end
  end
end

# Implements a BEGIN loop. Reads into the block until an UNTIL is found.
# Evaluates by repeatedy popping a value off the stack and evaluating
# its block until the value is non-zero.
class ForthBegin < ForthAdvObj
  def initialize(line, source, bad_on_empty)
    super(source, bad_on_empty)
    @block = []
    @remainder = read_until(line, @block, 'until')
  end

  def read_line(line)
    read_until(line, @block, 'until')
  end

  def eval(interpreter)
    return warn "#{SYNTAX} 'BEGIN' without closing 'UNTIL'" unless @good

    top = interpreter.stack.pop
    return warn STACK_UNDERFLOW if top.nil?

    while top.zero?
      interpreter.interpret_line(@block.dup, true)
      top = interpreter.stack.pop
      return warn STACK_UNDERFLOW if top.nil?
    end
  end
end

# frozen_string_literal: true

SYNTAX =   '[SYNTAX]'
BAD_TYPE = '[BAD_TYPE]'
BAD_DEF =  '[BAD_DEF]'
BAD_WORD = '[BAD_WORD]'
BAD_LOOP = '[BAD_LOOP]'
BAD_ADDRESS = '[BAD_ADDRESS]'
STACK_UNDERFLOW = '[STACK_UNDERFLOW]'

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

# The way this works, is that the interpreter converts
# keywords in the input into ForthObj's, and does two things
# Call eval(self) on the object to evaluate the word.
# Continute parsing on obj.remainder. This second step
# is so that complex words like IF, that have to parse input
# themselves can return the remainder of the line after
# they finish parsing (becauase if they have to read a new line from
# the input the original one is gone. )

# Common Operations for any math operations
# Base class for all Forth objects. All inherit from this so that testing for f
# orth objects is easy, using is_a?(ForthObj)
class ForthObj
  attr_reader :remainder
end

# Parent class for all keyword Forth words. I.e no IFs or strings.
# initialize has * so that it can take any number of arguments,
# as the interpeter treats all objects the same and will pass
# too many arguments to the constructor. Later classes do use
# these additional arguments.
class ForthWord < ForthObj
  def initialize(line, *)
    super()
    @remainder = line
  end

  private

  def check_nil(ops, stack)
    ops.each do |op|
      next unless op.nil?

      warn "#{STACK_UNDERFLOW} #{ops}"
      ops.reverse.each { |o| o.nil? ? nil : stack.push(o) }
      return true
    end
    false
  end
end

# All math operations inherit from this, becauase
# they all do basically the same thing.
class ForthMath < ForthWord
  def initialize(line, opr)
    super(line)
    @opr = opr
  end

  def eval(interpreter)
    mathop(interpreter.stack)
  end

  private

  def mathop(stack)
    op1 = stack.pop
    op2 = stack.pop
    return if check_nil([op1, op2], stack)

    result = begin
      op2.send(@opr, op1)
    rescue ZeroDivisionError
      0
    end
    stack << result unless check_nil([op1, op2], stack)
  end
end

# Forth Add operation
class ForthAdd < ForthMath
  def initialize(line, *)
    super(line, :+)
  end
end

# Forth Sub operation
class ForthSub < ForthMath
  def initialize(line, *)
    super(line, :-)
  end
end

# Forth * operation
class ForthMul < ForthMath
  def initialize(line, *)
    super(line, :*)
  end
end

# Forth / operation
class ForthDiv < ForthMath
  def initialize(line, *)
    super(line, :/)
  end
end

# Forth mod operation
class ForthMod < ForthMath
  def initialize(line, *)
    super(line, :%)
  end
end

# Forth and operation
class ForthAnd < ForthMath
  def initialize(line, *)
    super(line, :&)
  end
end

# Forth or operation
class ForthOr < ForthMath
  def initialize(line, *)
    super(line, :|)
  end
end

# Forth xor operation
class ForthXor < ForthMath
  def initialize(line, *)
    super(line, :^)
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
    print "#{op} " unless check_nil([op], interpreter.stack)
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
  def eval(interpreter)
    print interpreter.stack
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
    print "#{op.to_s[0].codepoints} " unless check_nil([op], interpreter.stack)
  end
end

# Forth Equal operation
class ForthEqual < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    (interpreter.stack << op1 == op2 ? -1 : 0) unless check_nil([op1, op2], interpreter.stack)
  end
end

# Forth Greater operation
class ForthGreater < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    (interpreter.stack << op2 > op1 ? -1 : 0) unless check_nil([op1, op2], interpreter.stack)
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
    (interpreter.stack << op2 < op1 ? -1 : 0) unless check_nil([op1, op2], interpreter.stack)
  end
end

# Forth Over operation
class ForthOver < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    interpreter.stack.insert(-1, op1, op2, op1) unless check_nil([op1, op2], interpreter.stack)
  end
end

# Forth Rot operation
class ForthRot < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    op3 = interpreter.stack.pop
    interpreter.stack.insert(-1, op2, op1, op3) unless check_nil([op1, op2, op3], interpreter.stack)
  end
end

# Forth Swap operation
class ForthSwap < ForthWord
  def eval(interpreter)
    op1 = interpreter.stack.pop
    op2 = interpreter.stack.pop
    interpreter.stack.insert(-1, op1, op2) unless check_nil([op1, op2], interpreter.stack)
  end
end

# Forth String. On eval, prints the line up to the first "
# character. Sets @remainder to the line after the ". If
# there is no ", it raises a warning on eval.
class ForthString < ForthObj
  def initialize(line, *)
    super()
    @good = line.include?('"')
    @remainder = line[line.index('"') + 1..] if @good
    @string = line[0..line.index('"') - 1] if @good
  end

  def eval(*)
    return warn "#{SYNTAX} No closing '\"' found" unless @good

    puts @string
  end
end

# Forth Comment. Behaves the same as ForthString, except doesn't print anything.
class ForthComment < ForthObj
  def initialize(line, *)
    super()
    @good = line.include?(')')
    @remainder = line[line.index(')') + 1..] if @good
    @string = line[0..line.index(')') - 1] if @good
  end

  def eval(*) end
end

# On eval, pushes the value in the heap at the address on the
# top of the stack to the top of the stack.
class ForthGetVar < ForthWord
  def initialize(line, *)
    super(line)
  end

  def eval(interpreter)
    return warn STACK_UNDERFLOW unless (addr = interpreter.stack.pop)

    interpreter.stack << interpreter.heap.get(addr)
  end
end

# On eval, sets the address on the top of the stack to the
# value on the second to top of the stack.
class ForthSetVar < ForthWord
  def initialize(line, *)
    super(line)
  end

  def eval(interpreter)
    return warn STACK_UNDERFLOW unless (addr = interpreter.stack.pop)

    return warn STACK_UNDERFLOW unless (val = interpreter.stack.pop)

    interpreter.heap.set(addr, val)
  end
end

# Parent class for Variable and Constant definition objects.
class ForthDefine < ForthObj
  def initialize(line, *)
    super()
    @name = line.shift
    @remainder = line
  end

  private

  def valid_def(name, interpreter, id)
    if name.nil?
      return warn "#{BAD_DEF} Empty #{id} definition"
    elsif @name.to_i.to_s == @name
      return warn "#{BAD_DEF} #{id.capitalize} names cannot be numbers"
    elsif interpreter.system?(@name)
      return warn "#{BAD_DEF} Cannot overrite existing words"
    end

    true
  end
end

# Defines a variable in the heap. On eval, allocate
# free space in the heap and store the address under '@name',
# which was read in as the first value on the line.
class ForthVariable < ForthDefine
  def eval(interpreter)
    return unless valid_def(@name, interpreter, 'variable')

    interpreter.heap.create(@name.downcase)
  end
end

# Defines a global constant. Sets @name to be the first value
# popped off the stack in the interpeter's constants list.
class ForthConstant < ForthDefine
  def eval(interpreter)
    return unless valid_def(@name, interpreter, 'constant')

    interpreter.constants[@name.downcase.to_sym] = interpreter.stack.pop
  end
end

# On eval, takes the top value of the stack as an address and
# allocates that much free space in the heap.
class ForthAllot < ForthDefine
  def eval(interpreter)
    return warn STACK_UNDERFLOW unless (addr = interpreter.stack.pop)

    interpreter.heap.allot(addr)
  end
end

# Doesn't do anything in this implementation.
class ForthCells < ForthWord
  def eval(*) end
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

  private

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

  def eval(interpreter)
    return warn "#{SYNTAX} 'DO' without closing 'LOOP'" unless @good

    start = interpreter.stack.pop
    limit = interpreter.stack.pop
    return warn "#{STACK_UNDERFLOW} #{[start, limit]}" if start.nil? || limit.nil?
    return warn "#{BAD_LOOP} Invalid loop range" if start.negative? || limit.negative?
    return warn "#{BAD_LOOP} Invalid loop range" if start > limit

    do_loop(interpreter, start, limit)
  end

  private

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

# Creates a user defined word. Reads in the name of the word,
# then copies the input as-is into @block. On eval, updates the
# interpreter's user_words hash with the new name and block.
class ForthWordDef < ForthAdvObj
  def initialize(line, source, *)
    super(source, false)
    @block = []
    @remainder = create_word(line)
  end

  def eval(interpeter)
    return warn "#{BAD_DEF} No name given" if @name.nil?
    return warn "#{BAD_DEF} Word already defined: #{@name}"\
    if interpeter.system?(@name) && !interpeter.user_words.key?(@name)

    interpeter.user_words[@name] = @block
  end

  private

  def create_word(line)
    return if line.empty?

    @name = line[0].downcase.to_sym
    read_word(line[1..])
  end

  # read words from stdin until a ';', storing
  # each word in the user_words hash under 'name'
  def read_word(line)
    read_word(@source.gets.split) if line.empty?
    word = line.shift
    return line if word == ';'
    return [] if word.nil?

    @block.push(word)
    read_word(line)
  end
end

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

# Base class for all Forth objects. All inherit from this so that testing for forth
# objects is easy, using is_a?(ForthObj). Every object of this type should have one
# public method, eval(interpreter), that takes an interpreter object and does the
# operation it represents. All objects should also have a remainder attribute, that
# is the remainder of the line after the object has been parsed.
class ForthObj
  attr_reader :remainder

  def initialize(*args)
    @remainder = args[0] if args.length.positive?
  end
end

# Parent class for all keyword Forth words. I.e no IFs or strings.
# Since these only take up a single word in the input, they
# always set remainder to the input line.
class ForthWord < ForthObj
  private

  def check_nil(values, stack)
    values.each do |val|
      next unless val.nil?

      warn "#{STACK_UNDERFLOW} #{values}"
      values.reverse.each { |v| v.nil? ? nil : stack.push(v) }
      return true
    end
    false
  end
end

# All math operations inherit from this, because the only
# difference between them is the operator they use.
class ForthMath < ForthWord
  def initialize(line, opr, *)
    super(line)
    @opr = opr
  end

  def eval(interpreter)
    mathop(interpreter.stack)
  end

  private

  def mathop(stack)
    v1 = stack.pop
    v2 = stack.pop
    return if check_nil([v1, v2], stack)

    result = begin
      v2.send(@opr, v1)
    rescue ZeroDivisionError
      0
    end
    stack << result unless check_nil([v1, v2], stack)
  end
end

# Forth + operation
class ForthAdd < ForthMath
  def initialize(line, *)
    super(line, :+)
  end
end

# Forth - operation
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

# Forth MOD operation
class ForthMod < ForthMath
  def initialize(line, *)
    super(line, :%)
  end
end

# Forth AND operation
class ForthAnd < ForthMath
  def initialize(line, *)
    super(line, :&)
  end
end

# Forth OR operation
class ForthOr < ForthMath
  def initialize(line, *)
    super(line, :|)
  end
end

# Forth XOR operation
class ForthXor < ForthMath
  def initialize(line, *)
    super(line, :^)
  end
end

# Forth CR operation (print newline)
class ForthCr < ForthWord
  def eval(_)
    puts ''
  end
end

# Forth . operation (Pops and prints top of stack)
class ForthDot < ForthWord
  def eval(interpreter)
    return if check_nil([v = interpreter.stack.pop], interpreter.stack)

    print "#{v} "
    interpreter.newline = true
  end
end

# Forth DROP operation. (Pops top of stack)
class ForthDrop < ForthWord
  def eval(interpreter)
    interpreter.stack.pop
  end
end

# Forth DUMP operation. (Prints stack)
class ForthDump < ForthWord
  def eval(interpreter)
    print interpreter.stack
    puts ''
  end
end

# Forth DUP operation. (Duplicates top of stack)
class ForthDup < ForthWord
  def eval(interpreter)
    interpreter.stack << (interpreter.stack.last) unless check_nil([interpreter.stack.last], interpreter.stack)
  end
end

# Forth EMIT operation. (Prints ASCII of top of stack)
class ForthEmit < ForthWord
  def eval(interpreter)
    return if check_nil([v = interpreter.stack.pop], interpreter.stack)

    print "#{v.to_s[0].codepoints} "
    interpreter.newline = true
  end
end

# Forth = operation
class ForthEqual < ForthWord
  def eval(interpreter)
    v1 = interpreter.stack.pop
    v2 = interpreter.stack.pop
    interpreter.stack << (v1 == v2 ? -1 : 0) unless check_nil([v1, v2], interpreter.stack)
  end
end

# Forth > operation
class ForthGreater < ForthWord
  def eval(interpreter)
    v1 = interpreter.stack.pop
    v2 = interpreter.stack.pop
    interpreter.stack << (v2 > v1 ? -1 : 0) unless check_nil([v1, v2], interpreter.stack)
  end
end

# Forth INVERT operation
class ForthInvert < ForthWord
  def eval(interpreter)
    interpreter.stack << (~interpreter.stack.pop)
  end
end

# Forth < operation
class ForthLesser < ForthWord
  def eval(interpreter)
    v1 = interpreter.stack.pop
    v2 = interpreter.stack.pop
    interpreter.stack << (v2 < v1 ? -1 : 0) unless check_nil([v1, v2], interpreter.stack)
  end
end

# Forth OVER operation. (Copies the second value on the stack in front of the first)
class ForthOver < ForthWord
  def eval(interpreter)
    v1 = interpreter.stack.pop
    v2 = interpreter.stack.pop
    interpreter.stack.insert(-1, v1, v2, v1) unless check_nil([v1, v2], interpreter.stack)
  end
end

# Forth ROT operation. (Rotates the order of the top three values on the stack)
class ForthRot < ForthWord
  def eval(interpreter)
    v1 = interpreter.stack.pop
    v2 = interpreter.stack.pop
    v3 = interpreter.stack.pop
    interpreter.stack.insert(-1, v2, v1, v3) unless check_nil([v1, v2, v3], interpreter.stack)
  end
end

# Forth SWAP operation. (Swaps the places of the first two stack elements)
class ForthSwap < ForthWord
  def eval(interpreter)
    v1 = interpreter.stack.pop
    v2 = interpreter.stack.pop
    interpreter.stack.insert(-1, v1, v2) unless check_nil([v1, v2], interpreter.stack)
  end
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
  def eval(_) end
end

# Parent class for Forth Words that can span multiple lines.
class ForthMultiLine < ForthObj
  def initialize(line, source, bad_on_empty, end_word: '')
    super()
    @source = source
    @good = true
    @bad_on_empty = bad_on_empty
    @remainder = read_until(line, @block = [], end_word) if line
  end

  private

  def read_until(line, block, end_word)
    while (word = line.shift) != end_word
      line = @source.gets.split if line.empty? && !@bad_on_empty
      return [] unless check_good(line)

      block << word if word
    end
    line
  end

  def check_good(line)
    if @bad_on_empty && line.empty?
      @good = false
      false
    else
      true
    end
  end
end

# Forth String. On eval, prints the line up to the first "
# character. Sets @remainder to the line after the ". If
# there is no ", it raises a warning on eval when bad_on_empty
# is true, otherwise it keeps reading until it finds one.
class ForthString < ForthMultiLine
  def initialize(*args)
    super(*args, end_word: '"')
  end

  def eval(interpreter)
    return warn "#{SYNTAX} No closing '\"' found" unless @good

    print "#{@block.join(' ')} "
    interpreter.newline = true
  end
end

# Forth Comment. Behaves the same as ForthString, except doesn't print anything.
class ForthComment < ForthMultiLine
  def initialize(*args)
    super(*args, end_word: ')')
  end

  def eval(_)
    return warn "#{SYNTAX} No closing ')' found" unless @good
  end
end

# Creates a user defined word. Reads in the name of the word,
# then copies the input as-is into @block. On eval, updates the
# interpreter's user_words hash with the new name and block.
class ForthWordDef < ForthMultiLine
  def initialize(line, source, *)
    @name = line.shift.downcase.to_sym if line
    super(line, source, false, end_word: ';')
  end

  def eval(interpeter)
    return warn "#{BAD_DEF} No name given" if @name.nil?
    return warn "#{BAD_DEF} Word already defined: #{@name}"\
    if interpeter.system?(@name.to_s) && !interpeter.user_words.key?(@name)

    interpeter.user_words[@name] = @block
  end
end

# Parent class for control operators like IF DO, and BEGIN.
# Shadows it's parent's read_until method, because
# it needs to handle ForthCntrlObjs differently on read.
class ForthCntrlObj < ForthMultiLine
  private

  def read_until(line, block, end_word)
    loop do
      line = @source.gets.split if line.empty? && !@bad_on_empty
      return [] unless check_good(line)
      break if (word = line.shift).downcase == end_word

      line = add_to_block(block, word, line)
    end
    line
  end

  # adds words into a block of the class. If the word read corresponds to a ForthCntrlObj, creates a
  # new instance immediately and starts reading into it rather than reading just the strings in.
  # This is because control objects can be nested, and if they weren't initialized immediately the
  # outermost object would stop at the first termination word, rather than the outermost (E.g if we
  # had IF IF THEN THEN, the first IF would stop at the first THEN, instead of the second.)
  def add_to_block(block, word, line)
    block << word = ForthCntrlObj.const_get("Forth#{word.capitalize}").new(line, @source, @bad_on_empty)
    word.remainder
    # if the above fails, it's a normal word.
  rescue NameError
    block << word
    line
  end
end

# Holds a forth IF statement. Calling read_line will start parsing the IF statement starting with
# the line given. Reads into the true_block until an ELSE or THEN is found, then reads into the
# false_block until a THEN is found if an ELSE was found. If another IF is encountered, creates a new
# ForthIf class, and starts it parsing on the rest of the line, resuming it's own parsing where that IF left off.
class ForthIf < ForthCntrlObj
  def initialize(line, source, bad_on_empty)
    super(nil, source, bad_on_empty)
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
    loop do
      line = @source.gets.split if line.empty? && !@bad_on_empty
      return [] unless check_good(line)
      return read_until(line, @false_block, 'then') if (word = line.shift).downcase == 'else'
      break if word.downcase == 'then'

      line = add_to_block(@true_block, word, line)
    end
    line
  end
end

# Implements a DO loop. Reads into the block until a LOOP is found.
# On calling eval it pops two values off the stack: the start and end values
# for the loop. (End non-inclusive) From this it builds the sequence
# of blocks needed to execute the loop. For each iteration, it duplicates
# the base block, and replaces any I in the block with the current iteration value.
class ForthDo < ForthCntrlObj
  def initialize(*args)
    super(*args, end_word: 'loop')
  end

  def eval(interpreter)
    return warn "#{SYNTAX} 'DO' without closing 'LOOP'" unless @good

    start = interpreter.stack.pop
    limit = interpreter.stack.pop
    return warn "#{STACK_UNDERFLOW} #{[limit, start]}" if start.nil? || limit.nil?
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
class ForthBegin < ForthCntrlObj
  def initialize(*args)
    super(*args, end_word: 'until')
  end

  def eval(interpreter)
    return warn "#{SYNTAX} 'BEGIN' without closing 'UNTIL'" unless @good

    # This should be the equivalent of the UNTIL popping the stack
    # and restarting at the BEGIN if non-zero.
    loop do
      interpreter.interpret_line(@block.dup, true)

      top = interpreter.stack.pop
      return warn STACK_UNDERFLOW if top.nil?
      break unless top.zero?
    end
  end
end
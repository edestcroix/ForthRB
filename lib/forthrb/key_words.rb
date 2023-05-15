# frozen_string_literal: true

require_relative 'utils'

# Base class for all Forth keywords. Each keyword on initialization takes in the line starting after
# the keyword so it can parse it as necessary. Whatever is leftover from parsing is stored in @remainder,
# so the interpreter can continue parsing from where the keyword left off. (I.e @remainder is the line after
# the keyword and any associated arguments) Each keyword has an eval method, which takes the interpreter as
# an argument, and uses the interpreter's methods to preform its operation on the interpreter's stack.
class ForthKeyWord
  attr_reader :remainder

  # Every forth keyword must take no more than two arguments
  # on creation, theese being the line to parse, and the input source to
  # get more lines from if necessary. (Sublcasses that don't get created
  # by the ForthInterpreter don't have to follow this rule.)
  def initialize(line, _)
    @remainder = line
  end

  private

  # checks if the stack has at least num non-nil values
  def underflow?(interpreter, num = 1)
    if (values = interpreter.stack.last(num).compact).length < num
      interpreter.err "#{STACK_UNDERFLOW} Stack contains #{values.length}/#{num} required value(s): #{values}."
      return true
    end
    false
  end
end

# All math operations inherit from this, because the only
# difference between them is the operator they use.
class ForthMathWord < ForthKeyWord
  def initialize(line, opr)
    super(line, nil)
    @opr = opr
  end

  def eval(interpreter)
    return if underflow?(interpreter, 2)

    (v1, v2) = interpreter.stack.pop(2)
    interpreter.stack << begin
      v1.send(@opr, v2)
    rescue ZeroDivisionError
      0
    end
  end
end

# Forth + operation
class ForthAdd < ForthMathWord
  def initialize(line, _)
    super(line, :+)
  end
end

# Forth - operation
class ForthSub < ForthMathWord
  def initialize(line, _)
    super(line, :-)
  end
end

# Forth * operation
class ForthMul < ForthMathWord
  def initialize(line, _)
    super(line, :*)
  end
end

# Forth / operation
class ForthDiv < ForthMathWord
  def initialize(line, _)
    super(line, :/)
  end
end

# Forth MOD operation
class ForthMod < ForthMathWord
  def initialize(line, _)
    super(line, :%)
  end
end

# Forth AND operation
class ForthAnd < ForthMathWord
  def initialize(line, _)
    super(line, :&)
  end
end

# Forth OR operation
class ForthOr < ForthMathWord
  def initialize(line, _)
    super(line, :|)
  end
end

# Forth XOR operation
class ForthXor < ForthMathWord
  def initialize(line, _)
    super(line, :^)
  end
end

# Forth CR operation (print newline)
class ForthCr < ForthKeyWord
  def eval(_)
    puts ''
  end
end

# Forth . operation (Pops and prints top of stack)
class ForthDot < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter)

    print ' ' if interpreter.space
    print interpreter.stack.pop
    interpreter.newline = true
    interpreter.space = true
  end
end

# Forth DROP operation. (Pops top of stack)
class ForthDrop < ForthKeyWord
  def eval(interpreter)
    interpreter.stack.pop
  end
end

# Forth DUMP operation. (Prints stack)
class ForthDump < ForthKeyWord
  def eval(interpreter)
    puts '' if interpreter.newline
    interpreter.newline = false
    interpreter.space = false
    puts "[#{interpreter.stack.join(', ')}]"
  end
end

# Forth DUP operation. (Duplicates top of stack)
class ForthDup < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter)

    interpreter.stack << interpreter.stack.last
  end
end

# Forth EMIT operation. (Prints ASCII of top of stack)
class ForthEmit < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter)

    print ' ' if interpreter.space
    print interpreter.stack.pop.to_s[0].codepoints.join(' ')
    interpreter.newline = true
    interpreter.space = true
  end
end

# Forth = operation
class ForthEqual < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter, 2)

    (v1, v2) = interpreter.stack.pop(2)
    interpreter.stack << (v1 == v2 ? -1 : 0)
  end
end

# Forth > operation
class ForthGreater < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter, 2)

    (v1, v2) = interpreter.stack.pop(2)
    interpreter.stack << (v1 > v2 ? -1 : 0)
  end
end

# Forth INVERT operation
class ForthInvert < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter)

    interpreter.stack << ~interpreter.stack.pop
  end
end

# Forth < operation
class ForthLesser < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter, 2)

    (v1, v2) = interpreter.stack.pop(2)
    interpreter.stack << (v1 < v2 ? -1 : 0)
  end
end

# Forth OVER operation. (Copies the second value on the stack in front of the first)
class ForthOver < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter, 2)

    (v1, v2) = interpreter.stack.pop(2)
    interpreter.stack.insert(-1, v1, v2, v1)
  end
end

# Forth ROT operation. (Rotates the order of the top three values on the stack)
class ForthRot < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter, 3)

    (v1, v2, v3) = interpreter.stack.pop(3)
    interpreter.stack.insert(-1, v2, v3, v1)
  end
end

# Forth SWAP operation. (Swaps the places of the first two stack elements)
class ForthSwap < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter, 2)

    (v1, v2) = interpreter.stack.pop(2)
    interpreter.stack.insert(-1, v2, v1)
  end
end

# On eval, pushes the value in the heap at the address on the
# top of the stack to the top of the stack.
class ForthGetVar < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter)

    interpreter.stack << interpreter.heap.get(interpreter.stack.pop)
  end
end

# On eval, sets the address on the top of the stack to the
# value on the second to top of the stack.
class ForthSetVar < ForthKeyWord
  def eval(interpreter)
    return if underflow?(interpreter, 2)

    (val, addr) = interpreter.stack.pop(2)
    interpreter.heap.set(addr, val)
  end
end

# Parent class for Variable and Constant definition objects.
class ForthVarDefine < ForthKeyWord
  include LineParse
  def initialize(line, _)
    @name = get_word(line)&.downcase
    super
  end

  private

  def valid_def(name, interpreter, id)
    if name.nil?
      return interpreter.err "#{SYNTAX} Empty #{id} definition"
    elsif @name.integer?
      return interpreter.err "#{BAD_DEF} #{id.capitalize} names cannot be numbers"
    elsif interpreter.system?(@name)
      return interpreter.err "#{BAD_DEF} '#{@name}' is already defined"
    end

    true
  end
end

# Defines a variable in the heap. On eval, allocate
# free space in the heap and store the address under '@name',
# which was read in as the first value on the line.
class ForthVariable < ForthVarDefine
  def eval(interpreter)
    return unless valid_def(@name, interpreter, 'variable')

    interpreter.heap.create(@name)
  end
end

# Defines a global constant. Sets @name to be the first value
# popped off the stack in the interpeter's constants list.
class ForthConstant < ForthVarDefine
  def eval(interpreter)
    return unless valid_def(@name, interpreter, 'constant')
    return if underflow?(interpreter)

    interpreter.constants[@name.to_sym] = interpreter.stack.pop
  end
end

# On eval, takes the top value of the stack as an address and
# allocates that much free space in the heap.
class ForthAllot < ForthVarDefine
  def eval(interpreter)
    return if underflow?(interpreter)

    interpreter.heap.allot(interpreter.stack.pop)
  end
end

# Doesn't do anything in this implementation.
class ForthCells < ForthKeyWord
  def eval(_) end
end

# Parent class for Forth Words that can span multiple lines.
class ForthMultiLine < ForthKeyWord
  include ClassConvert
  include LineParse
  def initialize(line, source, end_word: '')
    super(line, nil)
    @source = source
    @good = true
    @end_word = end_word
    @block = []
    @remainder = read_until(line) if line
  end

  private

  def read_until(line)
    loop do
      (return [] unless (line = read_source)) if line.empty?
      break if (word = get_word(line)) && word.casecmp?(@end_word)

      line = add_to_block(word, line)
    end
    line
  end

  # Adds words read from the input line to the @block (as in: code block) list. If the word corresponds to
  # a ForthKeyWord subclass, it creates said object from the word and parses it from
  # the line as needed before adding it to the block.
  def add_to_block(word, line)
    if (obj = str_to_class(word)&.new(line, @source))
      @block << obj
      return obj.remainder
    end

    @block << word if word
    line
  end

  # Reads the next line from the source. If there is no next line,
  # sets @good to false and returns nil. On eval, objects will print warnings
  # if @good is false.
  def read_source
    @good = false unless (line = @source.gets)
    line
  end
end

# Forth String. On eval, prints the line up to the first "
# character. Sets @remainder to the line after the ". If
# there is no ", it raises a warning on eval when stop_if_empty
# is true, otherwise it keeps reading until it finds one.
class ForthString < ForthMultiLine
  def initialize(line, source, end_word: '"')
    super(line, source, end_word: end_word)
  end

  def eval(interpreter)
    return interpreter.err "#{SYNTAX} No closing '\"' found" unless @good

    print @string
    interpreter.newline = true
    interpreter.space = false
  end

  private

  def read_until(line)
    # read input exactly as it appears until a " character
    @string = String.new
    until (i = line.index(@end_word))
      @string << line
      return [] unless (line = read_source)
    end
    @string << (i.zero? ? '' : line[0..i - 1])
    @string = @string[1..] if @string.start_with?(' ')
    line[i + 1..].strip
  end
end

# Forth Comment. Behaves the same as ForthString, except doesn't print anything.
class ForthComment < ForthString
  def initialize(line, source)
    super(line, source, end_word: ')')
  end

  def eval(interpreter)
    return interpreter.err "#{SYNTAX} No closing ')' found" unless @good
  end
end

# Creates a user defined word. Reads in the name of the word,
# then copies the input as-is into @block. On eval, updates the
# interpreter's user_words hash with the new name and block.
class ForthWordDef < ForthMultiLine
  def initialize(line, source)
    @name = get_word(line)&.downcase
    @remainder = line
    return if @name.nil? || @name == ';'

    super(line, source, end_word: ';')
  end

  def eval(interpreter)
    return interpreter.err "#{BAD_DEF} No name given for word definition" if @name.nil? || @name == ';'
    return interpreter.err "#{BAD_DEF} Word names cannot be builtins or variable names" \
    if interpreter.system?(@name) && !interpreter.user_words.key?(@name.to_sym)
    return interpreter.err "#{BAD_DEF} Word names cannot be numbers" if @name.integer?
    return interpreter.err "#{SYNTAX} ':' without closing ';'" unless @good

    interpreter.user_words[@name.to_sym] = @block
  end
end

# Holds a forth IF statement. Reads into @true_block until it finds an ELSE or THEN. If
# it finds a THEN, it reads into @false_block until it finds a THEN. On eval, pops
# the top of the stack and if it's 0, evaluates @false_block, otherwise @true_block.
class ForthIf < ForthMultiLine
  def initialize(line, source)
    super(line, source, end_word: 'then')
    else_index = @block.find_index { |s| s.is_a?(String) && s.casecmp?('else') } || @block.length
    @false_block = @block[else_index + 1..]
    @true_block = @block[0...else_index]
  end

  def eval(interpreter)
    # If the IF is not good (there wasn't an ending THEN) warn and do nothing.
    return interpreter.err "#{SYNTAX} 'IF' without closing 'THEN'" unless @good
    return if underflow?(interpreter)

    if interpreter.stack.pop.zero?
      interpreter.interpret_line(@false_block.dup) if @false_block
    else
      interpreter.interpret_line(@true_block.dup)
    end
  end
end

# Implements a DO loop. Reads into the @block until a LOOP is found.
# On calling eval it pops two values off the stack: the start and end values
# for the loop. (End non-inclusive) From this it builds the sequence
# of blocks needed to execute the loop. For each iteration, it duplicates
# the base block, and replaces any I in the block with the current iteration value.
class ForthDo < ForthMultiLine
  def initialize(line, source)
    super(line, source, end_word: 'loop')
  end

  def eval(interpreter)
    return interpreter.err "#{SYNTAX} 'DO' without closing 'LOOP'" unless @good
    return if underflow?(interpreter, 2)

    (limit, start) = interpreter.stack.pop(2)
    return warn "#{BAD_LOOP} Invalid loop range" if start.negative? || limit.negative? || start > limit

    do_loop(interpreter, start, limit)
  end

  private

  # for each iteration from start to limit, set I to the current value,
  # and interpret the block using the interprer. Stop looping if interpret_line
  # returs false, as this means an unknown word was encountered.
  def do_loop(interpreter, start, limit)
    (start...limit).each do |i|
      block = @block.dup.map { |w| w.is_a?(String) && w.casecmp?('i') ? i.to_s : w }
      break unless interpreter.interpret_line(block)
    end
  end
end

# Implements a BEGIN loop. Reads into the block until an UNTIL is found.
# Evaluates by repeatedy popping a value off the stack and evaluating
# its block until the value is non-zero.
class ForthBegin < ForthMultiLine
  def initialize(line, source)
    super(line, source, end_word: 'until')
  end

  def eval(interpreter)
    return interpreter.err "#{SYNTAX} 'BEGIN' without closing 'UNTIL'" unless @good

    loop do
      break unless interpreter.interpret_line(@block.dup)

      # NOTE: Should STACK_UNDERFLOW be raised if the stack is empty, or should the loop just halt?
      return if underflow?(interpreter)
      break unless interpreter.stack.pop.zero?
    end
  end
end

# loads and runs a file.
class ForthLoadFile < ForthKeyWord
  include LineParse
  def initialize(line, _)
    @filename = get_word(line)
    super
  end

  def eval(interpreter)
    return interpreter.err "#{BAD_LOAD} No filename given" unless @filename

    interpreter.load(@filename)
  end
end

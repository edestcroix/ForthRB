# TODO: Add comments
# - Word interpreter that can detect ." and " .
# - Check that AND OR, and XOR do what their supposed to.
# - When words are implemented, need to figure out what to do
#   when evaluating them
# - IF parser
# - Loop parser

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

  def mathop(opr)
    op1 = pop
    op2 = pop
    push(op2.send(opr, op1)) unless check_nil([op1, op2])
  end

  def equal
    op1 = pop
    op2 = pop
    (push op1 == op2 ? -1 : 0) unless check_nil([op1, op2])
  end

  def less_than
    op1 = pop
    op2 = pop
    (push op2 < op1 ? -1 : 0) unless check_nil([op1, op2])
  end

  def greater_than
    op1 = pop
    op2 = pop
    (push op2 < op1 ? -1 : 0) unless check_nil([op1, op2])
  end

  def dup
    op = pop
    insert(-1, op, op) unless check_nil([op])
  end

  def drop
    pop
  end

  def swap
    op1 = pop
    op2 = pop
    insert(-1, op1, op2) unless check_nil([op1, op2])
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

  def invert
    push(~pop)
  end

  def cr
    puts ''
  end

  def dump
    # print the stack in a human-readable format,
    # in reverse because the stack opeated on
    # from the end of the array
    print self
    puts ''
  end

  def dot
    op = pop
    print "#{op} " unless check_nil([op])
  end

  def emit
    # print ASCII of the top of the stack
    op = pop
    print "#{op.to_s.codepoints[0]} " unless check_nil([op])
  end

  private

  def check_nil(ops)
    # if any of the operands are nil, return true
    ops.each do |op|
      next unless op.nil?

      warn 'Stack underflow'
      # put the operands back on the stack, in the correct order
      ops.reverse.each { |o| o.nil? ? nil : push(o) }
      return true
    end
    false
  end
end

# interpreturn of forth
class ForthInterpreter
  def initialize(stack)
    @stack = stack
    @user_words = {}
  end

  def interpret
    $stdin.each_line do |line|
      line == "quit\n" ? exit(0) : interpret_line(mod_line(line))
      puts 'ok'
    end
  end

  private

  def interpret_line(line)
    line.split.each_with_index do |word, i|
      word = word.downcase
      eval_user_word(word) if @user_words.key?(word.to_sym)
      case eval_word(word)
      when 1
        interpret_word(line.split[i + 1..])
      when 2
        interpret_string(line.split[i + 1..])
      end
    end
  end

  def eval_word(word)
    return 1 if word == ':'
    return 2 if work == '."'

    if word =~ /\d+/
      @stack.push(word.to_i)
    elsif @stack.respond_to?(word)
      @stack.send(word.to_sym)
    else
      warn "Unknown word: #{word}"
    end
  end

  def mod_line(line)
    # replace + with add, - with sub, * with mul, etc
    line = line.gsub('+', 'add')
    line = line.gsub('-', 'sub')
    line = line.gsub('*', 'mul')
    line = line.gsub('/', 'div')
    line = line.gsub('=', 'equal')
    line = line.gsub('.', 'dot')
    line = line.gsub('<', 'less_than')
    line.gsub('>', 'greater_than')
  end

  def interpret_word(line)
    # evaluate lines until the ":", at which
    # point initialize a new word with the next
    # element in the line as the key,
    # then call the word interpreter on the
    # rest of the line

    name = line[0].downcase.to_sym
    if @stack.respond_to?(name)
      warn "Word already defined: #{word}"
    else
      @user_words.store(name, [])
      remainder = line[1..]
      read_word(remainder, name)
    end
  end

  def read_word(line, name)
    # read words from stdin until a ';', storing
    # each word in the user_words hash under 'name'
    found = false
    line.each do |word|
      found = true if word == ';'
      found ? (eval_word(word.downcase) if word != ';') : @user_words[name].push(word)
    end
    return if found

    # if no ; is found, read another from sdin
    read_word($stdin.gets.split, name)
  end

  def eval_user_word(word)
    puts @user_words[word.to_sym].inspect
    @user_words[word.to_sym].each do |w|
      eval_word(w.downcase)
    end
  end
end

stack = ForthStack.new

stack.push(5)
stack.push(6)
stack.push(7)
stack.push(8)
stack.push(9)
stack.add
stack.dot
stack.emit

stack.swap
stack.dump

forth = ForthInterpreter.new(stack)
forth.interpret

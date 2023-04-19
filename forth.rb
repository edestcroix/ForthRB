# TODO: 
# - Add comments
# - Word interpreter that can detect ." and ".       
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
    push(op1.send(opr, op2)) unless check_nil([op1, op2])
  end

  def equal
    op1 = pop
    op2 = pop
    push op1 == op2 ? -1 : 0
  end

  def less_than
    op1 = pop
    op2 = pop
    (push op1 < op2 ? -1 : 0) unless check_nil([op1, op2])
  end

  def greater_than
    op1 = pop
    op2 = pop
    (push op1 < op2 ? -1 : 0) unless check_nil([op1, op2])
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
    if check_nil([op1, op2])
      insert(-1, op2, op1)
    else
      insert(-1, op1, op2)
    end
  end

  def over
    op1 = pop
    op2 = pop
    check_nil([op1, op2]) ? insert(-1, op2, op1) : insert(-1, op2, op1, op2)
  end

  def rot
    op1 = pop
    op2 = pop
    op3 = pop
    if check_nil([op1, op2, op3])
      [op3, op2, op1].each { |op| op.nil? ? nil : insert(-1, op) }
    else
      insert(-1, op2, op1, op3)
    end
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
    print reverse
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
      if op.nil?
        warn 'Stack underflow'
        return true
      end
    end
    false
  end
end


class MethodMapper

  def initialize(stack)
    @stack = stack
    @words = {
      "+": @stack.method(:add),
      "-": @stack.method(:sub),
      "*": @stack.method(:mul),
      "/": @stack.method(:div),
      "=": @stack.method(:equal),
      ".": @stack.method(:dot),
      "dump": @stack.method(:dump),
      "over": @stack.method(:over),
      "cr": @stack.method(:cr),
      "rot": @stack.method(:rot),
      "invert": @stack.method(:invert),
      "drop": @stack.method(:drop),
      "swap": @stack.method(:swap),
      "emit": @stack.method(:emit),
      "and": @stack.method(:and),
      "or": @stack.method(:or),
      "xor": @stack.method(:xor),
      "dup": @stack.method(:dup)
    }
  end

  def lookup(word)
    @words[word.to_sym]
  end

  def key?(word)
    @words.key?(word.to_sym)
  end
end

# interpreturn of forth
class ForthInterpreter
  def initialize(stack)
    @stack = stack
    @map = MethodMapper.new(stack)
    @user_words = {}
  end

  def interpret
    $stdin.each_line do |line|
      if line == "quit\n"
        exit(0)
      # if the line has a ':', enter the
      # word interpreter
      elsif line =~ /:/
        interpret_word(line)
      else
        interpret_line(line)
      end
      puts 'ok'
    end
  end

  private

  def interpret_line(line)
    line.split.each do |word|
      word = word.downcase
      if @user_words.key?(word.to_sym)
        eval_user_word(word)
      else
        eval_word(word)
      end
    end
  end

  def eval_word(word)
    if word =~ /\d+/
      @stack.push(word.to_i)
    elsif @map.key?(word.to_sym)
      @map.lookup(word.to_sym).call
    else
      warn "Unknown word: #{word}"
    end
  end

  def interpret_word(line)
    # evaluate lines until the ":", at which
    # point initialize a new word with the next
    # element in the line as the key,
    # then call the word interpreter on the
    # rest of the line

    found = false
    index = 0
    line.split.each do |word|
      if word == ':'
        found = true
      elsif found
        name = word.downcase.to_sym
        if @map.key?(name)
          warn "Word already defined: #{word}"
        else
          @user_words.store(name, [])
          remainder = line.split[index + 1..]
          read_word(remainder, name)
        end
        break
      else
        eval_word(word)
      end
      index += 1
    end
  end

  def read_word(line, name)
    # read a word until the ";", then store
    # the word in the @user_words hash
    found = false
    line.each do |word|
      if word == ';'
        found = true
        break
      end
      @user_words[name].push(word)
    end
    # if no ; is found, read another from sdin
    return if found
 
    new_line = $stdin.gets
    read_word(new_line.split, name)
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

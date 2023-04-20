# TODO: Add comments
# - Only print newlines in output when neccessary.
# - Check that AND OR, and XOR do what they're supposed to.
# - IF parser (Do as a class?)
# - Loop parser (Do as a class?)

# NOTE: Idea for IF and LOOP
# When the IF/LOOP keywores are found, enter their
# parsers like for the words and strings, but store them into a class.
# Once the IF/LOOP is parsed, it is returned, and then
# call the newly created classes eval() method and pass it the stack as an argument.
# Then the classes can figure out what to evaluate. This shouldn't be too hard for regular parsing,
# but when evaluating a user word it might get tricky. Either save the raw IF/LOOP in the word,
# or build the classes during parsing and store them in the word, and have special cases for evaluating them.
# If done with the latter, could store strings as classes too.

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

  def lesser
    op1 = pop
    op2 = pop
    (push op2 < op1 ? -1 : 0) unless check_nil([op1, op2])
  end

  def greater
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

# interpreturn of forth
class ForthInterpreter
  def initialize(stack = ForthStack.new)
    @stack = stack
    @user_words = {}
    @symbol_map = { '+' => 'add', '-' => 'sub', '*' => 'mul', '/' => 'div',
                    '=' => 'equal', '.' => 'dot', '<' => 'lesser', '>' => 'greater' }
  end

  def interpret
    $stdin.each_line do |line|
      %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line.split)
      puts 'ok'
    end
  end

  private

  def interpret_line(line)
    return if line.empty?

    word = line.shift.downcase
    if @user_words.key?(word.to_sym)
      eval_user_word(@user_words[word.to_sym])
    else
      case word
      when '."'
        # eval_string returns the line after the string,
        # so continue the interpreter on this part.
        interpret_line(eval_string(line)) unless line.empty?
        return
      when ':'
        # TODO: Make interpret_word behave like eval_string,
        # in that it returns the line after the word definition.
        # (Don't really need to do this, but nice for consistency)
        interpret_word(line)
        return
      else
        eval_word(word, true)
      end
    end
    interpret_line(line) unless line.empty?
  end

  def interpret_word(line)
    # evaluate lines until the ":", at which
    # point initialize a new word with the next
    # element in the line as the key,
    # then call the word interpreter on the
    # rest of the line

    if line[0].nil?
      warn 'No word name given'
      return
    end
    name = line[0].downcase.to_sym
    if @stack.respond_to?(name) || @symbol_map.key?(name.to_sym)
      warn "Word already defined: #{name}"
    else
      @user_words.store(name, [])
      read_word(line[1..], name)
    end
  end

  def read_word(line, name)
    # read words from stdin until a ';', storing
    # each word in the user_words hash under 'name'
    found = false
    line.each do |word|
      found = true if word == ';'
      found ? (eval_word(word.downcase, true) if word != ';') : @user_words[name].push(word)
    end
    return if found

    # if no ; is found, read another from sdin
    read_word($stdin.gets.split, name)
  end

  def eval_string(line)
    # everything on the line should be printed as-is
    # until a " is found. if one isn't, error.
    # everything after the " should be evaluated
    if line.include?('"')
      print line[0..line.index('"') - 1].join(' ')
      print ' '
      line[line.index('"') + 1..]
    else
      warn 'No closing " found'
      []
    end
  end

  def eval_word(word, print)
    if word =~ /\d+/
      print "#{word} " if print
      @stack.push(word.to_i)
    elsif @symbol_map.key?(word)
      @stack.send(@symbol_map[word].to_sym)
    elsif !@symbol_map.value?(word) && @stack.respond_to?(word)
      @stack.send(word.to_sym)
    else
      warn "Unknown word: #{word}"
    end
  end

  def eval_user_word(word_list)
    return if word_list.empty?

    w = word_list.shift.downcase
    if w == '."'
      eval_user_word(eval_string(word_list))
    else
      eval_word(w, false)
      eval_user_word(word_list) unless word_list.empty?
    end
  end
end

ForthInterpreter.new.interpret

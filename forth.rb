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

  # Recursevely iterates over the line passed to it,
  # evaluating the words as it goes. When encountering user
  # defined words, calls eval_user_word. When encountering string
  # or user word definition start characters, passes the rest of the list
  # into the appropriate interpreters.
  def interpret_line(line)
    return if line.nil? || line.empty?

    word = line.shift.downcase
    if @user_words.key?(word.to_sym)
      # eval_user_word consumes its input. Have to clone it.
      eval_user_word(@user_words[word.to_sym].map(&:clone))
      interpret_line(line) unless line.empty?
    else
      dispatch(line, word)
    end
  end

  # figures out what to do with non-user defined words.
  # (because user defined words are the easy ones)
  def dispatch(line, word)
    case word
    when '."'
      # eval_string returns the line after the string,
      # so continue the interpreter on this part.
      interpret_line(eval_string(line))
    when ':'
      interpret_line(interpret_word(line))
    else
      eval_word(word, true)
      interpret_line(line)
    end
  end

  # evaluate lines until the ":", at which point initialize a new word
  # with the next element in the line as the key, then read every
  # word until a ";" is found into the user_words hash.
  def interpret_word(line)
    return warn 'Empty word definition' if line.empty?

    name = line[0].downcase.to_sym
    # This blocks overwriting system keywords, while still allowing
    # for user defined words to be overwritten.
    if @stack.respond_to?(name) || @symbol_map.key?(name.to_sym) || name =~ /\d+/
      warn "Word already defined: #{name}"
    else
      @user_words.store(name, [])
      read_word(line[1..], name)
    end
  end

  # TODO: Prevent certain words from being
  # added to user defined words. In particular,
  # don't allow word definition inside a word definition.
  # Might also be good to have error checking
  # while defining the word, not just when evaluating it. But
  # that's less important.

  # read words from stdin until a ';', storing
  # each word in the user_words hash under 'name'
  def read_word(line, name)
    read_word($stdin.gets.split, name) if line.empty?
    word = line.shift
    return line if word == ';'
    return [] if word.nil?

    @user_words[name].push(word)
    read_word(line, name)
  end

  # prints every word in the line until a " is found,
  # then returns the rest of the line.
  def eval_string(line)
    if line.include?('"')
      print line[0..line.index('"') - 1].join(' ')
      print ' '
      line[line.index('"') + 1..]
    else
      warn 'No closing " found'
      []
    end
  end

  # evaluate a word. If it's a number, push it to the stack,
  # and print it. Otherwise, if it is a symbol in the symbol_map,
  # call the corresponding method on the stack from the symbol_map.
  # Otherwise, if it is a method on the stack, call it.
  # If it is none of these, warn the user.
  def eval_word(word, print)
    if word =~ /\d+/
      print "#{word} " if print
      @stack.push(word.to_i)
    elsif @symbol_map.key?(word)
      @stack.send(@symbol_map[word].to_sym)
    elsif valid_word(word)
      @stack.send(word.to_sym)
    else
      warn "Unknown word: #{word}"
    end
  end

  # checks if the word is a valid word. This is done to make sure keywords that are Ruby array
  # methods don't get called. (Before eval_word just tested for stack.respond_to?
  # which caused problems) Only checks for specific keywords, because at this point
  # it has already been checked for being a user word, or a number or symbol.
  def valid_word(word)
    return false if word.nil?
    return false if word == ';'
    return false unless %w[dup drop swap over rot invert cr dump emit].include?(word)

    true
  end

  # Iterate over the user defined word, evaluating each word
  # in the list. Can evaluate strings currently.
  # TODO: Once IFs and LOOPs are implemented,
  # this will have to handle them somehow.
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

# frozen_string_literal: true

require 'forth_interpreter/version'
require 'forth_interpreter/key_words'
require 'forth_interpreter/utils'

# Main interpreter class. Holds the stack, and the dictionary of
# user defined words. The dictionary is a hash of words to arrays
# of words. Two methods are public: interpret and interpret_line.
# interpret repeatedly calls interpret_line on lines read
# from the source definied on creation. interpret_line takes
# an array of words and evaluates them on the stack.
class ForthInterpreter
  attr_reader :stack, :heap, :constants, :user_words
  # strings, '.', and eval don't print newlines after they are called, so they instead
  # update this variable so the interpreter will print one before the next prompt.
  attr_accessor :newline

  def initialize(source)
    @source = source
    @stack = []
    @heap = ForthVarHeap.new
    @constants = {}
    @user_words = {}
    @newline = false
    @symbol_map = { '+' => 'add', '-' => 'sub', '*' => 'mul', '/' => 'div',
                    '=' => 'equal', '.' => 'dot', '<' => 'lesser', '>' => 'greater',
                    '."' => 'string', '(' => 'comment', '!' => 'set_var', '@' => 'get_var', ':' => 'word_def' }
  end

  # runs the interpreter on the source provided on creation.
  def interpret
    while (line = @source.gets(true))
      %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line.split, false)
      puts '' if @newline
      @newline = false
    end
  end

  # Interprets a line of Forth code. line is an array of words.
  # bad_on_empty determines whether parsers should warn if they find an empty line,
  # or keep reading from stdin until they reach their terminating words.
  def interpret_line(line, bad_on_empty)
    while (w = line.shift)
      # if eval_word sets l to a non-nil value, update line to l as
      # l stores the remainder of the line after the word was evaluated.
      if (l = eval_word(w, line, bad_on_empty))
        line = l
      elsif @user_words.key?(w.downcase.to_sym)
        interpret_line(@user_words[w.downcase.to_sym].dup, true)
      else
        eval_value(w.downcase)
      end
    end
  end

  # Identifies if a word is a system word or a user defined word,
  # to prevent word or variable definitions overwriting system ones.
  def system?(word)
    !klass(name(word)).nil? || @user_words.key?(word.to_sym) || @constants.key?(word)
  end

  # Just calling 'warn' will put error messages on the same line as the output
  # from the '.' and EMIT keywords, and strings. This way, they get put on a new line.
  def err(msg)
    msg = "\n#{msg}" if @newline
    @newline = false
    warn msg
  end

  private

  # Evaluates a word object. Evaluates directly if the word is
  # already an object, otherwise creates and evaluates an object
  # based on the string name of the word.
  def eval_word(word, line, bad_on_empty)
    if word.is_a?(ForthKeyWord)
      word.eval(self)
      line
    elsif (obj = klass(name(word)))
      obj = obj.new(line, @source, bad_on_empty)
      obj.eval(self)
      obj.remainder
    end
  end

  # Handles 'value' type words. I.e numbers, variables, or constants that need to be pushed to the stack.
  def eval_value(word)
    if word.to_i.to_s == word
      @stack.push(word.to_i)
    elsif @heap.defined?(word)
      @stack.push(@heap.get_address(word))
    elsif @constants.key?(word.to_sym)
      @stack.push(@constants[word.to_sym])
    else
      invalid_word(word)
    end
  end

  # Sends the appropriate warning message based on the word.
  def invalid_word(word)
    return warn "#{SYNTAX} ';' without opening ':'" if word == ';'
    return warn "#{SYNTAX} 'LOOP' without opening 'DO'" if word == 'loop'
    return warn "#{SYNTAX} 'UNTIL' without opening 'BEGIN'" if word == 'until'
    return warn "#{SYNTAX} '#{word.upcase}' without opening 'IF'" if %w[else then].include?(word)

    warn "#{BAD_WORD} Unknown word '#{word}'"
  end

  # Converts a word string into a class name. Prevents using
  # class names directly in the interpreter, by only allowing words from the symbol
  # map or the keywords list. In the case of the symbol map, does not allow the
  # converted value to be used directly. (I.e + -> add, but if word is 'add' it
  # will not be converted to 'ForthAdd', only '+' will.)
  def name(word)
    return '' if word.nil? || @symbol_map.value?(word.downcase)

    word = @symbol_map.fetch(word.downcase, word.to_s.gsub('_', ''))
    "Forth#{word.split('_').map!(&:capitalize).join('')}"
  end

  # Handles converting a string into a class name, with
  # error handling for non-existant classes
  def klass(class_name)
    ForthKeyWord.const_get(class_name)
  rescue NameError
    nil
  end
end

# frozen_string_literal: true

require_relative 'forth_methods'

# Source is a wrapper around the input source, so that
# the interpreter can get its input from an abstracted
# interface. This allows it to read from a file or stdin,
# and also allows it to print the prompt before each line.
# This way, the interpreter itself does not have to
# deal with prompts, it only has to call gets on the source,
# and the source will handle the prompt and printing as requested.
# If the source is initialized with alt_print set to true,
# it will never print a prompt, and instead print the line it gets.
class Source
  def initialize(source, alt_print: false)
    @source = source
    @print_line = alt_print
  end

  def gets(prompt: false)
    print '> ' if prompt && !@print_line
    line = @source.gets
    puts "> #{line}" if @print_line && prompt
    puts line if @print_line && !prompt
    line
  end
end

# Main interpreter class. Holds the stack, and the dictionary of
# user defined words. The dictionary is a hash of words to arrays
# of words. Two methods are public: interpret and interpret_line.
# interpret repeatedly calls interpret_line on lines read
# from the source definied on creation. interpret_line takes
# an array of words and evaluates them on the stack.
class ForthInterpreter
  attr_reader :stack, :heap, :constants, :user_words

  def initialize(source)
    @source = source
    @stack = []
    @heap = ForthHeap.new
    @constants = {}
    @user_words = {}
    @keywords = %w[cr drop dump dup emit invert over rot swap variable constant allot cells if do begin]
    @symbol_map = { '+' => 'add', '-' => 'sub', '*' => 'mul', '/' => 'div',
                    '=' => 'equal', '.' => 'dot', '<' => 'lesser', '>' => 'greater',
                    '."' => 'string', '(' => 'comment', '!' => 'set_var', '@' => 'get_var', ':' => 'word_def' }
  end

  # runs the interpreter on the source provided on creation.
  def interpret
    while (line = @source.gets(prompt: true))
      %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line.split, false)
      puts 'ok'
    end
  end

  # Interprets a line of Forth code. line is an array of words.
  # bad_on_empty determines whether parsers should warn if they find an empty line,
  # or keep reading from stdin until the reach their terminating words.
  def interpret_line(line, bad_on_empty)
    return if invalid_line?(line)

    if (w = line.shift).is_a?(ForthObj)
      w.eval(self)
    elsif @user_words.key?(w.downcase.to_sym)
      interpret_line(@user_words[w.downcase.to_sym].dup, true)
    else
      line = eval_word(w, line, bad_on_empty)
    end
    interpret_line(line, bad_on_empty)
  end

  def system?(word)
    @keywords.include?(word) || @symbol_map.key?(word)\
    || @user_words.key?(word.to_sym) || @constants.key?(word)
  end

  private

  # putting this here instead of just having in interpret_line directly
  # stopped rufocop from having a hissy fit for ABC complexity so I've left it.
  def invalid_line?(line)
    line.nil? || line.empty?
  end

  # Calls the appropriate function based on the word.
  def eval_word(word, line, bad_on_empty)
    if (new_obj = klass(name(word)))
      eval_obj(new_obj, line, bad_on_empty)
    else
      eval_value(word)
      line
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
    return warn "#{SYNTAX} '#{word.upcase}' without opening 'IF'" if %w[else then].include?(word)

    warn "#{BAD_WORD} Unknown word '#{word}'"
  end

  # Converts a word string into a class name. Prevents using
  # class names directly in the interpreter, by only allowing words from the symbol
  # map or the keywords list. In the case of the symbol map, does not allow the
  # converted value to be used directly. (I.e + -> add, but if word is 'add' it
  # will not be converted to 'ForthAdd', onky '+' will.)
  def name(word)
    word = if (w = @symbol_map[word.downcase])
             w
           elsif !@keywords.include?(word.downcase)
             'bad'
           else
             word
           end
    "Forth#{word.split('_').map!(&:capitalize).join('')}"
  end

  def eval_obj(obj, line, bad_on_empty)
    (new_obj = obj.new(line, @source, bad_on_empty)).eval(self)
    new_obj.remainder
  end

  def klass(class_name)
    Module.const_get(class_name)
  rescue NameError
    nil
  end
end

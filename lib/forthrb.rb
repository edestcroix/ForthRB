# frozen_string_literal: true

require 'forthrb/version'
require 'forthrb/key_words'
require 'forthrb/utils'

# Main interpreter class. Holds the stack, and the dictionary of
# user defined words. The dictionary is a hash of words to arrays
# of words. Two methods are public: interpret and interpret_line.
# interpret repeatedly calls interpret_line on lines read
# from the source definied on creation. interpret_line takes
# an array of words and evaluates them on the stack.
class ForthInterpreter
  include ClassConvert
  attr_reader :stack, :heap, :constants, :user_words
  # strings, '.', and eval don't print newlines after they are called, so they instead
  # update this variable so the interpreter will print one before the next prompt.
  attr_accessor :newline

  def initialize(source)
    @source = Source.new(source)
    @stack = []
    @heap = ForthVarHeap.new
    @constants = {}
    @newline = false
    @user_words = {}
  end

  # runs the interpreter on the source provided on creation.
  def interpret
    while (line = @source.gets(prompt: true))
      %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line.split, false)
      puts '' if @newline
      @newline = false
    end
  end

  # Interprets a line of Forth code. line is an array of either strings, ForthKeyWords,
  # or both. bad_on_empty determines whether parsers should warn if they find an empty line,
  # or keep reading from stdin until they reach their terminating words.
  def interpret_line(line, bad_on_empty)
    while (word = line.shift)
      # if eval_word sets l to a non-nil value, update line to l as
      # l stores the remainder of the line after the word was evaluated.
      if (l = eval_word(word, line, bad_on_empty))
        line = l
      elsif @user_words.key?((word = word.downcase).to_sym)
        interpret_line(@user_words[word.to_sym].dup, true)
      else
        break unless eval_value(word)
      end
    end
  end

  # reads from a file by temporarily changing the source to a new Source object
  # and calling interpret. If the file is not found, warn the user.
  def load(file)
    old_source = @source
    File.expand_path! file
    return warn "#{BAD_LOAD} File '#{file}' not found" unless File.exist?(file)

    @source = Source.new(File.open(file))
    interpret
    puts "\e[32mLoaded #{file} successfully\e[0m"
    @source = old_source
  end

  # Identifies if a word is a system word or a user defined word,
  # to prevent word or variable definitions overwriting system ones.
  def system?(word)
    !str_to_class(word).nil? || @user_words.key?(word.to_sym) || @constants.key?(word.to_sym) || @heap.defined?(word)
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
    if word.is_a? ForthKeyWord
      word.eval(self)
      line
    elsif (obj = str_to_class(word))
      obj = obj.new(line, @source, bad_on_empty)
      obj.eval(self)
      obj.remainder
    end
  end

  # Handles 'value' type words. I.e numbers, variables, or constants that need to be pushed to the stack.
  def eval_value(word)
    # integer? method added by extending String in utils.rb
    if word.integer?
      @stack << word.to_i
    elsif @heap.defined? word
      @stack << @heap.get_address(word)
    elsif @constants.key? word.to_sym
      @stack << @constants[word.to_sym]
    else
      return err_invalid word
    end
    true
  end

  # Sends the appropriate warning message based on the word.
  def err_invalid(word)
    return err "#{SYNTAX} ';' without opening ':'" if word == ';'
    return err "#{SYNTAX} 'LOOP' without opening 'DO'" if word == 'loop'
    return err "#{SYNTAX} 'UNTIL' without opening 'BEGIN'" if word == 'until'
    return err "#{SYNTAX} '#{word.upcase}' without opening 'IF'" if %w[else then].include?(word)

    err "#{BAD_WORD} Unknown word '#{word}'"
  end
end

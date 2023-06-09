# frozen_string_literal: true

require 'forthrb/version'
require 'forthrb/forth_ops'

# TODO: - Rewrite comments to align with Rubys RSpec/Yard docs format
#       - Test coverage

module ForthRB
  # Main interpreter class. Holds the stack, and the dictionary of
  # user defined words. The dictionary is a hash of words to arrays
  # of words. Two methods are public: interpret and interpret_line.
  # interpret repeatedly calls interpret_line on lines read
  # from the source definied on creation. interpret_line takes
  # an array of words and evaluates them on the stack.
  class ForthInterpreter
    include ForthOps
    attr_reader :stack, :heap, :constants, :user_words

    # booleans to determine if newlines or spaces should be printed in interpreter/keyword outputs
    # Updated as needed by the interpreter and relevent keywords.
    attr_accessor :newline, :space

    def initialize(source)
      @source = Source.new(source)
      @stack = []
      @heap = ForthHeap.new
      @constants = {}
      @user_words = {}
      @newline = false
      @space = false
    end

    # runs the interpreter on the source provided on creation.
    def interpret
      while (line = @source.gets(prompt: true))
        %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line)
        puts '' if @newline
        @space = false
        @newline = false
      end
    end

    # Interprets a line of Forth code. Accepts either a String of space-separated words,
    # or an Array of Strings or ForthOps. For general input, (from stdin or otherwise) line should
    # be the String read so that strings in the input can be parsed with the correct whitespace.
    def interpret_line(line)
      while (word = get_word(line))
        # if eval_word sets l to a non-nil value, update line to l as
        # l stores the remainder of the line after the word was evaluated.
        if (l = eval_word(word, line))
          line = l
        elsif @user_words.key?(w = word.downcase.to_sym)
          interpret_line(@user_words[w].dup)
        else
          return false unless eval_value(word)
        end
      end
      true
    end

    # reads from a file by temporarily changing the source to a new Source object
    # and calling interpret. If the file is not found, warn the user.
    def load_file(file)
      old_source = @source
      file = File.expand_path file
      return err(BAD_LOAD, file: file) unless File.exist?(file)

      @source = Source.new(File.open(file))
      interpret
      puts "\e[32mLoaded #{file} successfully\e[0m"
      @source = old_source
    end

    # Identifies if a word is a system word or a user defined word,
    # to prevent word or variable definitions overwriting system ones.
    def system?(word)
      !str_to_forth_op(word).nil? || @user_words.key?(word.to_sym) \
      || @constants.key?(word.to_sym) || @heap.defined?(word)
    end

    # Just calling 'warn' will put error messages on the same line as the output
    # from the '.' and EMIT keywords, and strings. This way, they get put on a new line.
    def err(msg, **args)
      msg = "\n#{msg}" if @newline
      @newline = false
      warn format(msg, args)
    end

    private

    # Evaluates a word object. Evaluates directly if the word is
    # already an object, otherwise creates and evaluates an object
    # based on the string name of the word.
    def eval_word(word, line)
      if word.is_a? ForthOps::ForthOp
        word.eval(self)
        line
      elsif (obj = str_to_forth_op(word))
        obj = obj.new(line, @source)
        obj.eval(self)
        obj.remainder
      end
    end

    # Handles 'value' type words. I.e numbers, variables, or constants that need to be pushed to the stack.
    def eval_value(word)
      if word.to_i.to_s == word
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
      return err(SYNTAX, have: word, need: ':') if word == ';'
      return err(SYNTAX, have: word, need: '."') if word == '"'
      return err(SYNTAX, have: word, need: 'DO') if word.casecmp?('loop')
      return err(SYNTAX, have: word, need: 'BEGIN') if word.casecmp?('until')
      return err(SYNTAX, have: word, need: 'IF') if %w[else then].any? { |w| word.casecmp?(w) }

      err(BAD_WORD, word: word)
    end
  end

  # Implements a Heap for the ForthInterpreter to store variables in.
  class ForthHeap
    def initialize
      @heap = []
      @name_map = {}
      @free = -1
    end

    def create(name)
      @free += 1
      @name_map[name.to_sym] = @free + 1000
    end

    def allot(size)
      @free += size
    end

    def get_address(name)
      @name_map[name.to_sym]
    end

    def defined?(name)
      @name_map.key?(name.to_sym)
    end

    def set(addr, value)
      return false if addr < 1000 || addr > 1000 + @free

      @heap[addr - 1000] = value
    end

    def get(address)
      return false if address.nil? || address < 1000 || address > 1000 + @free

      @heap[address - 1000]
    end
  end

  # Source is a wrapper around STDIN and File objects to allow the ForthInterpreter
  # to read from either and handle the prompt/output appropriately. On initialization,
  # the ForthInterpreter takes a source (anything that has a gets method really),
  # and wraps it in a Source object.
  class Source
    def initialize(source)
      @source = source
      @is_stdin = source == $stdin
    end

    def gets(prompt: false)
      print '> ' if prompt && @is_stdin
      line = @source.gets
      print "> #{line}" if !@is_stdin && line
      line
    end
  end
end

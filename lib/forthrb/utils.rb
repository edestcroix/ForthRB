# frozen_string_literal: true

# Error Codes
SYNTAX = "\e[31m[SYNTAX]\e[0m"
BAD_TYPE = "\e[31m[BAD TYPE]\e[0m"
BAD_DEF = "\e[31m[BAD DEF]\e[0m"
BAD_WORD = "\e[31m[BAD WORD]\e[0m"
BAD_LOOP = "\e[31m[BAD LOOP]\e[0m"
BAD_ADDRESS = "\e[31m[BAD ADDRESS]\e[0m"
STACK_UNDERFLOW = "\e[31m[STACK UNDERFLOW]\e[0m"

# Implements a Heap for the ForthInterpreter to store variables in.
class ForthVarHeap
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
    return warn "#{BAD_ADDRESS} #{address}" if address.nil?
    return warn "#{BAD_ADDRESS} #{address}" if address < 1000 || address > 1000 + @free

    @heap[address - 1000]
  end
end

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

  def gets(prompt = nil?)
    print '> ' if prompt
    line = @source.gets
    print line if @print_line
    line
  end
end

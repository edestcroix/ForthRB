# frozen_string_literal: true

# Error Codes
SYNTAX = "\e[31m[SYNTAX]\e[0m"
BAD_TYPE = "\e[31m[BAD TYPE]\e[0m"
BAD_DEF = "\e[31m[BAD DEF]\e[0m"
BAD_WORD = "\e[31m[BAD WORD]\e[0m"
BAD_LOOP = "\e[31m[BAD LOOP]\e[0m"
BAD_ADDRESS = "\e[31m[BAD ADDRESS]\e[0m"
STACK_UNDERFLOW = "\e[31m[STACK UNDERFLOW]\e[0m"
BAD_LOAD = "\e[31m[BAD LOAD]\e[0m"

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

# Source is a wrapper around STDIN and File objects to allow the ForthInterpreter
# to read from either and handle the prompt/output appropriately. On initialization,
# the ForthInterpreter takes a source (anything that has a gets method really),
# and wraps it in a Source object. STDIN is wrapped with prompt_firstset to true,
# so the prompt is printed before the input, and files are wrapped with prompt_first
# set to false, which prints out the prompt and the line read from the file.
class Source
  def initialize(source, prompt_first: false)
    @source = source
    @print_line = prompt_first
  end

  def gets(prompt = nil?)
    print '> ' if prompt && @print_line
    line = @source.gets
    print "> #{line}" if !@print_line && line
    line
  end
end
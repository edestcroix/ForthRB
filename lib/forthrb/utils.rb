# frozen_string_literal: true

# Error Codes
SYNTAX = "\e[31m[SYNTAX]\e[0m"
BAD_DEF = "\e[31m[BAD DEF]\e[0m"
BAD_WORD = "\e[31m[BAD WORD]\e[0m"
BAD_LOOP = "\e[31m[BAD LOOP]\e[0m"
BAD_ADDRESS = "\e[31m[BAD ADDRESS]\e[0m"
STACK_UNDERFLOW = "\e[31m[STACK UNDERFLOW]\e[0m"
BAD_LOAD = "\e[31m[BAD LOAD]\e[0m"

# Common methods for parsing input lines.
module LineParse
  def get_word(line)
    return line.shift unless line.is_a?(String)

    line.replace(line[1..]) if line.start_with?(' ')
    word = line.slice!(/\S+/)
    line.replace('') unless word
    word
  end
end

# extend String class to add integer check.
class String
  def integer?
    to_i.to_s == self
  end
end

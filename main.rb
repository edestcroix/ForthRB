# frozen_string_literal: true

require_relative 'forth_methods'

# TODO: Add comments
# - Check that AND OR, and XOR do what they're supposed to.
# - BEGIN loop.
# - Figure out better code layout, because right now some of this is CRAP.
#   What I might want to do is create a class
#   for each word type, and have them all have
#   an eval method that takes in the stack and evals
#   itself. Then the parser just converts strings into objects
#   and calls eval on them. Then if it finds a if, etc
#   key word, it will read whatever is needed and create
#   an if class or whatever and store it in the list

@stack = ForthStack.new
@user_words = {}
@keywords = %w[cr drop dump dup emit invert over rot swap]
@symbol_map = { '+' => 'add', '-' => 'sub', '*' => 'mul', '/' => 'div',
                '=' => 'equal', '.' => 'dot', '<' => 'lesser', '>' => 'greater' }


# starting here, a line is read in from stdin. From this point, various recursive calls
# are made to parse the line and evaluate it. The main function, interpret_line,
# recursively iterates over the input line, and in the basic case just calls eval_word
# to perform a simple action on the stack. If it is something more complicated like a
# comment or string, it calls another method, which reads the line the same way as
# interpret_line, but performs different actions. When these functions find the word
# that terminates the block they are reading, they return whatever is after back out,
# and another recursive interpret_line call is made on whatever comes after.

def interpret
  print '> '
  $stdin.each_line do |line|
    %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line.split, false)
    puts 'ok'
    print '> '
  end
end

# Interprets a line of Forth code. line is an array of words.
# bad_on_empty determines whether parsers should warn if they find an empty line,
# or keep reading from stdin until the reach their terminating words.
def interpret_line(line, bad_on_empty)
  return if invalid_line?(line)

  if (w = line.shift).is_a?(ForthObj)
    line = w.eval(@stack).dup
    bad_on_empty = true
  elsif @user_words.key?(w.downcase.to_sym)
    # eval_user_word consumes its input. Have to clone it.
    interpret_line(@user_words[w.downcase.to_sym].dup, true)
  else
    line = dispatch(w, line, bad_on_empty)
  end
  interpret_line(line, bad_on_empty)
end

# putting this here instead of just having in interpret_line directly
# stopped rufocop from having a hissy fit for ABC complexity so I've left it.
def invalid_line?(line)
  line.nil? || line.empty?
end

# Calls the appropriate function based on the word.
# Calls func on the rest of the line after the word has been evaluated.
def dispatch(word, line, bad_on_empty)
  case word.downcase
  when '."'
    eval_string(line)
  when ':'
    create_word(line)
  when '('
    eval_comment(line)
  when 'do'
    eval_obj(ForthDo, line, bad_on_empty)
  when 'if'
    eval_obj(ForthIf, line, bad_on_empty)
  else
    eval_word(word.downcase)
    line
  end
end

def eval_obj(obj, line, bad_on_empty)
  new_obj = obj.new(bad_on_empty)
  line = new_obj.read_line(line)
  interpret_line(new_obj.eval(@stack), bad_on_empty)
  line
end

# evaluate lines until the ":", at which point initialize a new word
# with the next element in the line as the key, then read every
# word until a ";" is found into the user_words hash.
def create_word(line)
  return warn "#{BAD_DEF} Empty word definition" if line.empty?

  name = line[0].downcase.to_sym
  # This blocks overwriting system keywords, while still allowing
  # for user defined words to be overwritten.
  # TODO: Fully account for all disallowed words.
  if @keywords.include?(name) || @symbol_map.key?(name.to_sym) || name =~ /\d+/
    warn "#{BAD_DEF} Word already defined: #{name}"
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
  return warn "#{SYNTAX} No closing '\"' found" unless line.include?('"')

  print line[0..line.index('"') - 1].join(' ')
  print ' '
  line[line.index('"') + 1..]
end

def eval_comment(line)
  return warn "#{SYNTAX} No closing ) found" unless line.include?(')')

  line[line.index(')') + 1..]
end

# evaluate a word. If it's a number, push it to the stack,
# and print it. Otherwise, if it is a symbol in the symbol_map,
# call the corresponding method on the stack from the symbol_map.
# Otherwise, if it is a method on the stack, call it.
# If it is none of these, warn the user.
def eval_word(word)
  if word.to_i.to_s == word
    @stack.push(word.to_i)
  elsif @symbol_map.key?(word)
    @stack.send(@symbol_map[word].to_sym)
  elsif valid_word(word)
    @stack.send(word.to_sym)
  end
end

# checks if the word is a valid word. This is done to make sure keywords that are Ruby array
# methods don't get called. (Before eval_word just tested for stack.respond_to?
# which caused problems) Only checks for specific keywords, because at this point
# it has already been checked for being a user word, or a number or symbol.
def valid_word(word)
  return false if word.nil?
  return warn "#{SYNTAX} ';' without opening ':'" if word == ';'
  return warn "#{SYNTAX} 'LOOP' without opening 'DO'" if word == 'loop'
  return warn "#{SYNTAX} '#{word.upcase}' without opening 'IF'" if %w[else then].include?(word)
  return warn "#{BAD_WORD} Unknown word '#{word}'" unless @keywords.include?(word)

  true
end

# frozen_string_literal: true

require_relative 'forth_methods'

# TODO: Add comments
# - Only print newlines in output when neccessary.
# - Check that AND OR, and XOR do what they're supposed to.
# - Loop parser (Do as a class?)

# NOTE: Idea for IF and LOOP
# When the IF/LOOP keywords are found, enter their
# parsers like for the words and strings, but store them into a class.
# Once the IF/LOOP is parsed, it is returned, and then
# call the newly created classes eval() method and pass it the stack as an argument.
# Then the classes can figure out what to evaluate. This shouldn't be too hard for regular parsing,
# but when evaluating a user word it might get tricky. Either save the raw IF/LOOP in the word,
# or build the classes during parsing and store them in the word, and have special cases for evaluating them.
# If done with the latter, could store strings as classes too.

@stack = ForthStack.new
@user_words = {}
@keywords = %w[cr drop dump dup emit invert over rot swap]
@symbol_map = { '+' => 'add', '-' => 'sub', '*' => 'mul', '/' => 'div',
                '=' => 'equal', '.' => 'dot', '<' => 'lesser', '>' => 'greater' }

def interpret
  print '> '
  $stdin.each_line do |line|
    %W[quit\n exit\n].include?(line) ? exit(0) : interpret_line(line.split)
    puts 'ok'
    print '> '
  end
end

# Interprets a line of Forth code.
def interpret_line(line)
  return if line.nil? || line.empty?

  word = line.shift.downcase
  if @user_words.key?(word.to_sym)
    # eval_user_word consumes its input. Have to clone it.
    eval_word_list(@user_words[word.to_sym].map(&:clone))
    interpret_line(line) unless line.empty?
  else
    dispatch(line, word)
  end
end

# figures out what to do with non-user defined words.
# (because user defined words are the easy ones)
# All methods other than eval_word take in the line
# that starts after their associated keyword and returns
# whatever is left on the line after their domain ends.
# (E.g, if a : is encountered, call create_word on the
# line after the :, it will continue parsing the word definition
# until it finds a ;, then return anything after the ;. )
def dispatch(line, word)
  case word
  when '."'
    interpret_line(eval_string(line))
  when ':'
    interpret_line(create_word(line))
  when '('
    interpret_line(eval_comment(line))
  when 'if'
    interpret_line(eval_if(line, false))
  else
    eval_word(word)
    interpret_line(line)
  end
end

def eval_if(line, bad_on_empty)
  new_if = ForthIf.new(bad_on_empty)
  line = new_if.read_line(line)
  eval_word_list(new_if.eval(@stack))
  line
end

# evaluate lines until the ":", at which point initialize a new word
# with the next element in the line as the key, then read every
# word until a ";" is found into the user_words hash.
def create_word(line)
  return warn 'Empty word definition' if line.empty?

  name = line[0].downcase.to_sym
  # This blocks overwriting system keywords, while still allowing
  # for user defined words to be overwritten.
  # TODO: Fully account for all disallowed words.
  if @keywords.include?(name) || @symbol_map.key?(name.to_sym) || name =~ /\d+/
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
  return warn 'No closing " found' unless line.include?('"')

  print line[0..line.index('"') - 1].join(' ')
  print ' '
  line[line.index('"') + 1..]
end

def eval_comment(line)
  return warn 'No closing ) found' unless line.include?(')')

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
  return false unless @keywords.include?(word)

  true
end

# Iterate over the user defined word, evaluating each word
# in the list. Can evaluate strings currently.
# TODO: Once LOOPs are implemented,
# this will have to handle them somehow.
def eval_word_list(word_list)
  return if word_list.nil? || word_list.empty?

  w = word_list.shift
  # yes, I made a weird function just so I could make this a one liner.
  return eval_if_and_cont(w, proc { eval_word_list(word_list) }) if w.is_a?(ForthIf)

  if @user_words.key?(w.downcase.to_sym)
    # eval_user_word consumes its input. Have to clone it.
    eval_word_list(@user_words[w.downcase.to_sym].map(&:clone))
    return eval_word_list(word_list) unless word_list.empty?
  end

  case w.downcase
  when '."'
    eval_word_list(eval_string(word_list))
  when '('
    eval_word_list(eval_comment(word_list))
  when 'if'
    eval_word_list(eval_if(word_list, true))
  else
    eval_word(w.downcase)
    eval_word_list(word_list) unless word_list.empty?
  end
end

def eval_if_and_cont(if_obj, continute_func)
  eval_word_list(if_obj.eval(@stack).map(&:clone))
  continute_func.call
end

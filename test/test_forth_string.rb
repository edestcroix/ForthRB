# frozen_string_literal: true

require 'rspec/autorun'
require 'forthrb'

describe ForthOps::FString do
  let(:interpreter) { ForthRB::ForthInterpreter.new($stdin) }

  it 'prints a string' do
    test_string = ForthOps::FString.new(String.new('hello world "'), $stdin)
    expect do
      test_string.eval(interpreter)
    end.to output('hello world ').to_stdout
  end

  it 'errors without end quote' do
    test_string = ForthOps::FString.new(String.new('hello world'), StringIO.new(''))
    expect do
      test_string.eval(interpreter)
    end.to output(format("#{SYNTAX}\n", have: '."', need: '"')).to_stderr
  end

  it 'reads more lines' do
    test_stdin = StringIO.new("\nhello world \"\n")
    test_string = ForthOps::FString.new(%w[hello world].join(' '), test_stdin)
    expect do
      test_string.eval(interpreter)
    end.to output("hello world\nhello world ").to_stdout
  end
end

describe ForthOps::FString do
  let(:interpreter) { ForthRB::ForthInterpreter.new($stdin) }
  let(:blank_stdin) { StringIO.new('') }

  it 'doesn\'t need space before end quote' do
    expect do
      ForthOps::FString.new('hello world"', StringIO.new('')).eval(interpreter)
    end.to output('hello world').to_stdout
  end

  it 'preserves whitespace' do
    expect do
      ForthOps::FString.new('hello   world"', StringIO.new('')).eval(interpreter)
    end.to output('hello   world').to_stdout

    expect do
      ForthOps::FString.new('hello   world   "', StringIO.new('')).eval(interpreter)
    end.to output('hello   world   ').to_stdout

    expect do
      ForthOps::FString.new("hello  \n  world   \"  ", StringIO.new('')).eval(interpreter)
    end.to output("hello  \n  world   ").to_stdout

    # first whitespace after the ." is always consumed by the interpreter, otherwise
    # it would not be recognized as a keyword.
    expect do
      # calling interpreter directly here because the whitespace after the ." can
      # be affected by the function call to get_word by whatever is parsing to get the ." out of the
      # line, in which case the ForthString has no control over that. (Basically, the whitespace after the
      # first word in the string is entirely the String's problem, but the whitespace after the ." can be affected
      # by whatever was parsing the line before the string)
      interpreter.interpret_line(String.new('."  hello" ."   world" ."    hi"'))
    end.to output(' hello  world   hi').to_stdout
  end
end

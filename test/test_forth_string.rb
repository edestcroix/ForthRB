# frozen_string_literal: true

require 'rspec/autorun'
require 'forthrb'

describe ForthString do
  let(:interpreter) { ForthInterpreter.new($stdin) }

  it 'prints a string' do
    test_string = ForthString.new(String.new('hello world "'), $stdin)
    expect do
      test_string.eval(interpreter)
    end.to output('hello world ').to_stdout
  end

  it 'errors without end quote' do
    test_string = ForthString.new(String.new('hello world'), StringIO.new(''))
    expect do
      test_string.eval(interpreter)
    end.to output("#{SYNTAX} No closing '\"' found\n").to_stderr
  end

  it 'reads more lines' do
    test_stdin = StringIO.new("\nhello world \"\n")
    test_string = ForthString.new(%w[hello world].join(' '), test_stdin)
    expect do
      test_string.eval(interpreter)
    end.to output("hello world\nhello world ").to_stdout
  end
end

describe ForthString do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:blank_stdin) { StringIO.new('') }

  it 'doesn\'t need space before end quote' do
    expect do
      ForthString.new('hello world"', StringIO.new('')).eval(interpreter)
    end.to output('hello world').to_stdout
  end

  it 'preserves whitespace' do
    expect do
      ForthString.new('hello   world"', StringIO.new('')).eval(interpreter)
    end.to output('hello   world').to_stdout

    expect do
      ForthString.new('hello   world   "', StringIO.new('')).eval(interpreter)
    end.to output('hello   world   ').to_stdout

    expect do
      ForthString.new("hello  \n  world   \"  ", StringIO.new('')).eval(interpreter)
    end.to output("hello  \n  world   ").to_stdout
  end
end

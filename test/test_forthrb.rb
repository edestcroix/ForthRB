# frozen_string_literal: true

require 'rspec/autorun'
require 'forthrb'

# TODO: Test Improvements:
# - Test all words (at least ones with unique behavior)
# - Test that words are case insensitive
# - Test file loading.
# - Make sure tests are organized in a way that makes sense, and
#   failures are easy to understand. Also make sure they have
#   good coverage.

describe ForthInterpreter do
  let(:interpreter) { ForthInterpreter.new($stdin) }

  it 'does math operations' do
    interpreter.interpret_line(%w[1 2 +])
    expect(interpreter.stack).to eq [3]
    interpreter.interpret_line(%w[4 -])
    expect(interpreter.stack).to eq [-1]
    interpreter.interpret_line(%w[3 *])
    expect(interpreter.stack).to eq [-3]
    interpreter.interpret_line(%w[-1 /])
    expect(interpreter.stack).to eq [3]
  end

  it 'does comparisons' do
    interpreter.interpret_line(%w[1 2 <])
    interpreter.interpret_line(%w[1 2 >])
    interpreter.interpret_line(%w[1 2 =])
    interpreter.interpret_line(%w[1 1 =])
    expect(interpreter.stack).to eq [-1, 0, 0, -1]
  end
end

describe ForthInterpreter do
  let(:output) { StringIO.new }
  let(:interpreter) { ForthInterpreter.new($stdin) }

  it 'prints newlines when needed' do
    $stdout = output
    $stdin = (input = StringIO.new('4 5 6 . . DUMP .'))
    interpreter.interpret
    output.rewind
    input.rewind
    expect(output.read).to eq "> 6 5\n[4]\n4\n> "
  end

  it 'prints newlines for errors' do
    $stdout = output
    $stderr = (err = StringIO.new)
    $stdin = (input = StringIO.new('4 5 6 . . DUMP . NOTAWORD'))
    interpreter.interpret
    output.rewind
    err.rewind
    input.rewind
    expect(output.read).to eq "> 6 5\n[4]\n4> "
    expect(err.read).to eq "\n#{BAD_WORD} Unknown word 'notaword'\n"
  end
end

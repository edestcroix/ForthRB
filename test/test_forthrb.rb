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

describe ForthRB::ForthInterpreter do
  let(:interpreter) { ForthRB::ForthInterpreter.new($stdin) }

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

describe ForthRB::ForthInterpreter do
  let(:output) { StringIO.new }
  let(:interpreter) { ForthRB::ForthInterpreter.new($stdin) }

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
    expect(err.read).to eq "\n#{format(BAD_WORD, word: 'NOTAWORD')}\n"
  end
end

describe ForthRB::ForthInterpreter do
  let(:interpreter) { ForthRB::ForthInterpreter.new($stdin) }
  # ForthRB::ForthInterpreter performs operation by attempting to convert
  # words in the input to classes in the ForthOps module. This test
  # ensures that classes outside of the module can't be created.
  it 'doesn\'t recognize non-ForthOps classes' do
    expect do
      interpreter.interpret_line('interpreter'.+@)
    end.to output(format("#{BAD_WORD}\n", word: 'interpreter')).to_stderr
    expect do
      interpreter.interpret_line('heap'.+@)
    end.to output(format("#{BAD_WORD}\n", word: 'heap')).to_stderr
  end
end

describe ForthRB::ForthHeap do
  let(:heap) { ForthRB::ForthHeap.new }

  it 'allocates a variable' do
    heap.create('test')

    expect(heap.instance_variable_get(:@name_map)).to include(test: 1000)
    expect(heap.instance_variable_get(:@free)).to eq(0)
  end

  it 'allocates space' do
    heap.allot(4) && heap.create('test')
    expect(heap.instance_variable_get(:@free)).to eq(4)
    expect(heap.instance_variable_get(:@name_map)).to include(test: 1004)
  end

  it 'returns variable address' do
    heap.create('test')
    expect(heap.get_address('test')).to eq(1000)
  end

  it 'sets a variable' do
    heap.create('test')
    heap.set(1000, 45)
    expect(heap.instance_variable_get(:@heap)).to eq([45])
  end

  it 'gets a variable' do
    heap.create('test')
    heap.set(1000, 45)
    expect(heap.get(1000)).to eq(45)
  end
end

describe ForthRB::ForthHeap do
  let(:heap) { ForthRB::ForthHeap.new }

  it 'returns false for invalid addresses' do
    expect(heap.get(103)).to eq(false)
    expect(heap.get(1000)).to eq(false)
    expect(heap.get(1001)).to eq(false)
  end

  it 'returns nil for unassigned addresses' do
    heap.create('test')
    expect(heap.get(1000)).to eq(nil)
  end
end

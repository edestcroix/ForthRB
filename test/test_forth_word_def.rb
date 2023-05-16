# frozen_string_literal: true

require 'rspec/autorun'
require 'forthrb'

describe ForthOps::WordDef do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  # deliberately put weird newlines in the input IO to make sure it reads correctly.
  let(:word_def) { ForthOps::WordDef.new(%w[test], StringIO.new("\n 1 2\n+ ;")) }

  it 'defines a word' do
    word_def.eval(interpreter)
    expect(interpreter.user_words).to include(test: %w[1 2] + [ForthOps::Add])
    interpreter.interpret_line(['test'])
    expect(interpreter.stack).to eq [3]
  end

  it 'supports recursion' do
    ForthOps::WordDef.new(%w[fac DUP 1 > IF DUP 1 - fac * ELSE DROP 1 THEN ;], $stdin).eval(interpreter)
    interpreter.interpret_line(%w[5 fac])
    expect(interpreter.stack).to eq [120]
  end

  it 'overwrites a word' do
    word_def.eval(interpreter)
    interpreter.interpret_line(%w[: test 3 4 + ;])
    expect(interpreter.user_words).to include(test: %w[3 4] + [ForthOps::Add])
  end
end

describe ForthOps::WordDef do
  let(:interpreter) { ForthInterpreter.new($stdin) }

  it 'prevents defining a word with a number' do
    expect do
      interpreter.interpret_line(%w[: 1 2 + ;])
    end.to output("#{BAD_DEF} Word names cannot be numbers\n").to_stderr
  end

  it 'prevents defining a word with a builtin name' do
    expect do
      interpreter.interpret_line(%w[: + 2 + ;])
    end.to output("#{BAD_DEF} Word names cannot be builtins or variable names\n").to_stderr
  end

  it 'errors without a name' do
    expect do
      interpreter.interpret_line(%w[: ;])
    end.to output("#{BAD_DEF} No name given for word definition\n").to_stderr
    expect do
      interpreter.interpret_line(%w[:])
    end.to output("#{BAD_DEF} No name given for word definition\n").to_stderr
  end
end

describe ForthOps::WordDef do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  it 'accepts complex words' do
    $stdin = StringIO.new(%(
: eggsize
DUP 18 < IF ." reject "
ELSE
DUP 21 < IF ." small "
ELSE
DUP 24 < IF ." medium "
ELSE
DUP 27 < IF ." large "
ELSE
DUP 30 < IF ." extra large " ELSE
." error "
THEN THEN THEN THEN THEN DROP ;
23 eggsize))
    expect do
      interpreter.interpret
      to output('medium ').to_stdout
    end
  end
end

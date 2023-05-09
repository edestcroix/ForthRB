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
    interpreter.interpret_line(%w[1 2 +], false)
    expect(interpreter.stack).to eq [3]
    interpreter.interpret_line(%w[4 -], false)
    expect(interpreter.stack).to eq [-1]
    interpreter.interpret_line(%w[3 *], false)
    expect(interpreter.stack).to eq [-3]
    interpreter.interpret_line(%w[-1 /], false)
    expect(interpreter.stack).to eq [3]
  end

  it 'does comparisons' do
    interpreter.interpret_line(%w[1 2 <], false)
    interpreter.interpret_line(%w[1 2 >], false)
    interpreter.interpret_line(%w[1 2 =], false)
    interpreter.interpret_line(%w[1 1 =], false)
    expect(interpreter.stack).to eq [-1, 0, 0, -1]
  end
end

describe ForthRot do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:rot) { ForthRot.new }

  it 'rotates the top 3 stack elements' do
    interpreter.interpret_line(%w[1 2 3], false)
    rot.eval(interpreter)
    expect(interpreter.stack).to eq [2, 3, 1]
  end

  it 'raises a stack underflow error' do
    expect do
      rot.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 0/3 required value(s): [].\n").to_stderr

    interpreter.interpret_line(%w[1], false)
    expect do
      rot.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 1/3 required value(s): [1].\n").to_stderr
  end
end

describe ForthSwap do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:swap) { ForthSwap.new }

  it 'swaps the top 2 stack elements' do
    interpreter.interpret_line(%w[1 2 3], false)
    swap.eval(interpreter)
    expect(interpreter.stack).to eq [1, 3, 2]
  end

  it 'raises a stack underflow error' do
    expect do
      swap.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 0/2 required value(s): [].\n").to_stderr

    expect do
      interpreter.interpret_line(%w[1], false)
      swap.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 1/2 required value(s): [1].\n").to_stderr
  end
end

describe ForthString do
  let(:interpreter) { ForthInterpreter.new($stdin) }

  it 'prints a string' do
    test_string = ForthString.new(%w[hello world "], $stdin, false)
    expect do
      test_string.eval(interpreter)
    end.to output('hello world ').to_stdout
  end

  it 'errors without end quote' do
    test_string = ForthString.new(%w[hello world], $stdin, true)
    expect do
      test_string.eval(interpreter)
    end.to output("#{SYNTAX} No closing '\"' found\n").to_stderr
  end

  it 'reads more lines' do
    test_stdin = StringIO.new("hello world \"\n")
    test_string = ForthString.new(%w[hello world], test_stdin, false)
    expect do
      test_string.eval(interpreter)
    end.to output('hello world hello world ').to_stdout
  end
end

describe ForthComment do
  let(:interpreter) { ForthInterpreter.new(StringIO.new) }

  it 'ignores a comment' do
    test_comment = ForthComment.new(%w[hello world )], $stdin, false)
    expect do
      test_comment.eval(interpreter)
    end.to_not output.to_stdout
  end

  it 'errors without end parenthesis' do
    test_comment = ForthComment.new(%w[hello world], $stdin, true)
    expect do
      test_comment.eval(interpreter)
    end.to output("#{SYNTAX} No closing ')' found\n").to_stderr
  end

  it 'reads more lines' do
    test_stdin = StringIO.new("hello world )\n")
    ForthComment.new(%w[hello world], test_stdin, false)
    expect(test_stdin.eof?).to be true
  end
end

describe ForthIf do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:stdin) { StringIO.new("\n3 4 +\n. else 5\n6 + .\nthen 4 5 6") }
  let(:forth_if) { ForthIf.new(%w[." hello world "], stdin, false) }

  it 'reads until else or then' do
    expect(forth_if.remainder).to eq %w[4 5 6]
  end

  it 'evaluates true' do
    expect do
      interpreter.interpret_line(%w[1], false)
      forth_if.eval(interpreter)
    end.to output('hello world 7 ').to_stdout
  end

  it 'evaluates false' do
    expect do
      interpreter.interpret_line(%w[0], false)
      forth_if.eval(interpreter)
    end.to output('11 ').to_stdout
  end

  it 'nests ifs' do
    test_if = ForthIf.new(%w[1 if 4 . else 3 . then then], $stdin, false)
    expect do
      interpreter.interpret_line(%w[1], false)
      test_if.eval(interpreter)
    end.to output('4 ').to_stdout
  end
end

describe ForthDo do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:stdin) { StringIO.new("\nrot dump\nloop 3 4") }
  let(:forth_do) { ForthDo.new(%w[I .], stdin, false) }

  # Test that it will read from the source until it finds a loop correctly.
  it 'reads until loop' do
    expect(forth_do.remainder).to eq %w[3 4]
    expect(forth_do.instance_variable_get(:@block)).to_not include(nil)
  end

  # Test that when bad_on_empty is true, it will error if there is no 'loop'.
  it 'errors without loop' do
    expect do
      ForthDo.new(%w[." hi "], $stdin, true).eval(interpreter)
    end.to output("#{SYNTAX} 'DO' without closing 'LOOP'\n").to_stderr
  end

  it 'loops' do
    expect do
      interpreter.interpret_line(%w[3 4 5 3 0], false)
      expect(interpreter.stack).to eq [3, 4, 5, 3, 0]
      forth_do.eval(interpreter)
    end.to output("0 \n[4, 5, 3]\n1 \n[5, 3, 4]\n2 \n[3, 4, 5]\n").to_stdout
  end

  it 'nests loops' do
    test_do = ForthDo.new(%w[3 0 DO 3 LOOP LOOP], $stdin, false)
    interpreter.interpret_line(['3', '0', test_do], false)
    expect(interpreter.stack).to eq [3, 3, 3, 3, 3, 3, 3, 3, 3]
  end
end

describe ForthWordDef do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  # deliberately put weird newlines in the input IO to make sure it reads correctly.
  let(:word_def) { ForthWordDef.new(%w[test], StringIO.new("\n 1 2\n+ ;"), false) }

  it 'defines a word' do
    word_def.eval(interpreter)
    expect(interpreter.user_words).to include(test: %w[1 2 +])
    interpreter.interpret_line(['test'], false)
    expect(interpreter.stack).to eq [3]
  end

  it 'supports recursion' do
    ForthWordDef.new(%w[fac DUP 1 > IF DUP 1 - fac * ELSE DROP 1 THEN ;], $stdin, false).eval(interpreter)
    interpreter.interpret_line(%w[5 fac], false)
    expect(interpreter.stack).to eq [120]
  end

  it 'errors without a name' do
    expect do
      interpreter.interpret_line(%w[: ;], false)
    end.to output("#{BAD_DEF} No name given for word definition\n").to_stderr
  end

  it 'overwrites a word' do
    word_def.eval(interpreter)
    interpreter.interpret_line(%w[: test 3 4 + ;], false)
    expect(interpreter.user_words).to include(test: %w[3 4 +])
  end
end

describe ForthWordDef do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  it 'prevents defining a word with a number' do
    expect do
      interpreter.interpret_line(%w[: 1 2 + ;], false)
    end.to output("#{BAD_DEF} Word names cannot be numbers\n").to_stderr
  end
  it 'prevents defining a word with a builtin name' do
    expect do
      interpreter.interpret_line(%w[: + 2 + ;], false)
    end.to output("#{BAD_DEF} Word names cannot be builtins or variable names\n").to_stderr
  end
end

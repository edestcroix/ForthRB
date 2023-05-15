# frozen_string_literal: true

require 'rspec/autorun'
require 'forthrb'

describe ForthRot do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:rot) { ForthRot.new(nil, nil) }

  it 'rotates the top 3 stack elements' do
    interpreter.interpret_line(%w[1 2 3])
    rot.eval(interpreter)
    expect(interpreter.stack).to eq [2, 3, 1]
  end

  it 'raises a stack underflow error' do
    expect do
      rot.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 0/3 required value(s): [].\n").to_stderr

    interpreter.interpret_line(%w[1])
    expect do
      rot.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 1/3 required value(s): [1].\n").to_stderr
  end
end

describe ForthSwap do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:swap) { ForthSwap.new(nil, nil) }

  it 'swaps the top 2 stack elements' do
    interpreter.interpret_line(%w[1 2 3])
    swap.eval(interpreter)
    expect(interpreter.stack).to eq [1, 3, 2]
  end

  it 'raises a stack underflow error' do
    expect do
      swap.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 0/2 required value(s): [].\n").to_stderr

    expect do
      interpreter.interpret_line(%w[1])
      swap.eval(interpreter)
    end.to output("#{STACK_UNDERFLOW} Stack contains 1/2 required value(s): [1].\n").to_stderr
  end
end

describe ForthVariable do
  let(:stdin) { StringIO.new("1 2 3\n") }
  let(:interpreter) { ForthInterpreter.new(stdin) }

  it 'creates a variable' do
    interpreter.interpret_line(String.new('variable test test'))
    expect(interpreter.stack).to eq [1000]
  end

  it 'errors without a name' do
    variable = ForthVariable.new(%w[], $stdin)
    expect do
      variable.eval(interpreter)
    end.to output("#{SYNTAX} Empty variable definition\n").to_stderr
  end

  it 'doesn\'t overwrite an existing variable' do
    interpreter.interpret_line(String.new('variable test'))
    expect do
      interpreter.interpret_line(%w[variable test])
    end.to output("#{BAD_DEF} 'test' is already defined\n").to_stderr
  end
end

describe ForthComment do
  let(:interpreter) { ForthInterpreter.new(StringIO.new) }

  it 'ignores a comment' do
    test_comment = ForthComment.new(String.new('hello world )'), $stdin)
    expect do
      test_comment.eval(interpreter)
    end.to_not output.to_stdout
  end

  it 'errors without end parenthesis' do
    test_comment = ForthComment.new(%w[hello world].join(' '), $stdin)
    expect do
      test_comment.eval(interpreter)
    end.to output("#{SYNTAX} No closing ')' found\n").to_stderr
  end

  it 'reads more lines' do
    test_stdin = StringIO.new("hello world )\n")
    ForthComment.new(%w[hello world].join(' '), test_stdin)
    expect(test_stdin.eof?).to be true
  end
end

describe ForthIf do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:stdin) { StringIO.new("\n3 4 +\n. else 5\n6 + .\nthen 4 5 6") }
  let(:forth_if) { ForthIf.new(%w[." hello world "].join(' '), stdin) }

  it 'reads until else or then' do
    expect(forth_if.instance_variable_get(:@true_block)).to include(ForthString, ForthAdd, ForthDot)
    expect(forth_if.instance_variable_get(:@false_block)).to include('5', '6', ForthAdd, ForthDot)
  end

  it 'evaluates true' do
    expect do
      interpreter.interpret_line(%w[1])
      forth_if.eval(interpreter)
    end.to output('hello world 7').to_stdout
  end

  it 'evaluates false' do
    expect do
      interpreter.interpret_line(%w[0])
      forth_if.eval(interpreter)
    end.to output('11').to_stdout
  end

  it 'nests ifs' do
    expect do
      interpreter.interpret_line(%w[1])
      ForthIf.new(%w[1 if 4 . else 3 . then then], $stdin).eval(interpreter)
    end.to output('4').to_stdout
  end
end

describe ForthDo do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:forth_do) { ForthDo.new(%w[I .].join(' '), StringIO.new("\nrot dump\nloop 3 4")) }

  # Test that it will read from the source until it finds a loop correctly.
  it 'reads until loop' do
    expect(forth_do.instance_variable_get(:@block)).to_not include(nil)
    expect(forth_do.instance_variable_get(:@block)).to include('I', ForthDot, ForthRot, ForthDump)
    expect do
      interpreter.interpret_line(%w[3 0 do 3 loop . . .].join(' '))
    end.to output('3 3 3').to_stdout
  end

  # Test that when stop_if_empty is true, it will error if there is no 'loop'.
  it 'errors without loop' do
    expect do
      ForthDo.new(%w[." hi "].join(' '), $stdin).eval(interpreter)
    end.to output("#{SYNTAX} 'DO' without closing 'LOOP'\n").to_stderr
  end

  it 'loops' do
    interpreter.interpret_line(%w[3 4 5 3 0])
    expect do
      forth_do.eval(interpreter)
    end.to output("0\n[4, 5, 3]\n1\n[5, 3, 4]\n2\n[3, 4, 5]\n").to_stdout
  end

  it 'nests loops' do
    test_do = ForthDo.new(%w[3 0 DO 3 LOOP LOOP], $stdin)
    interpreter.interpret_line(['3', '0', test_do])
    expect(interpreter.stack).to eq [3, 3, 3, 3, 3, 3, 3, 3, 3]
  end
end

describe ForthBegin do
  let(:stdin) { StringIO.new("\n 4 5 + . .\"  HI \" UNTIL") }
  let(:interpreter) { ForthInterpreter.new(stdin) }
  let(:forth_begin) { ForthBegin.new(%w[1 .].join(' '), stdin) }

  it 'reads until until' do
    expect(forth_begin.instance_variable_get(:@block)).to_not include(nil)
    expect(forth_begin.instance_variable_get(:@block)).to_not include('UNTIL')
  end

  it 'errors without until' do
    expect do
      ForthBegin.new(%w[." hi "].join(' '), $stdin).eval(interpreter)
    end.to output("#{SYNTAX} 'BEGIN' without closing 'UNTIL'\n").to_stderr
  end

  it 'loops' do
    interpreter.interpret_line(%w[3 4 5 0 0 0])
    expect do
      forth_begin.eval(interpreter)
    end.to output('1 9 HI 1 9 HI 1 9 HI 1 9 HI ').to_stdout
  end
end

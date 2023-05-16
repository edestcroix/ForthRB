# frozen_string_literal: true

require 'rspec/autorun'
require 'forthrb'

describe ForthOps::Rot do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:rot) { ForthOps::Rot.new(nil, nil) }

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

describe ForthOps::Swap do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:swap) { ForthOps::Swap.new(nil, nil) }

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

describe ForthOps::Variable do
  let(:stdin) { StringIO.new("1 2 3\n") }
  let(:interpreter) { ForthInterpreter.new(stdin) }

  it 'creates a variable' do
    interpreter.interpret_line(String.new('variable test test'))
    expect(interpreter.stack).to eq [1000]
  end

  it 'errors without a name' do
    variable = ForthOps::Variable.new(%w[], $stdin)
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

describe ForthOps::Comment do
  let(:interpreter) { ForthInterpreter.new(StringIO.new) }

  it 'ignores a comment' do
    test_comment = ForthOps::Comment.new(String.new('hello world )'), $stdin)
    expect do
      test_comment.eval(interpreter)
    end.to_not output.to_stdout
  end

  it 'errors without end parenthesis' do
    test_comment = ForthOps::Comment.new(%w[hello world].join(' '), $stdin)
    expect do
      test_comment.eval(interpreter)
    end.to output("#{SYNTAX} No closing ')' found\n").to_stderr
  end

  it 'reads more lines' do
    test_stdin = StringIO.new("hello world )\n")
    ForthOps::Comment.new(%w[hello world].join(' '), test_stdin)
    expect(test_stdin.eof?).to be true
  end
end

describe ForthOps::If do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:stdin) { StringIO.new("\n3 4 +\n. else 5\n6 + .\nthen 4 5 6") }
  let(:forth_if) { ForthOps::If.new(%w[." hello world "].join(' '), stdin) }

  it 'reads until else or then' do
    expect(forth_if.instance_variable_get(:@true_block)).to include(ForthOps::FString, ForthOps::Add,
                                                                    ForthOps::Dot)
    expect(forth_if.instance_variable_get(:@false_block)).to include('5', '6', ForthOps::Add, ForthOps::Dot)
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
end

describe ForthOps::If do
  let(:interpreter) { ForthInterpreter.new($stdin) }

  it 'does nothing with false and no else' do
    expect do
      interpreter.interpret_line('0 if 3 . then'.+@)
    end.to_not output.to_stdout
  end

  it 'nests ifs' do
    expect do
      interpreter.interpret_line(%w[1])
      ForthOps::If.new(%w[1 if 4 . else 3 . then then], $stdin).eval(interpreter)
    end.to output('4').to_stdout
  end
end

describe ForthOps::Do do
  let(:interpreter) { ForthInterpreter.new($stdin) }
  let(:forth_do) { ForthOps::Do.new(%w[I .].join(' '), StringIO.new("\nrot dump\nloop 3 4")) }

  # Test that it will read from the source until it finds a loop correctly.
  it 'reads until loop' do
    expect(forth_do.instance_variable_get(:@block)).to_not include(nil)
    expect(forth_do.instance_variable_get(:@block)).to include('I', ForthOps::Dot, ForthOps::Rot, ForthOps::Dump)
    expect do
      interpreter.interpret_line(%w[3 0 do 3 loop . . .].join(' '))
    end.to output('3 3 3').to_stdout
  end

  # Test that when stop_if_empty is true, it will error if there is no 'loop'.
  it 'errors without loop' do
    expect do
      ForthOps::Do.new(%w[." hi "].join(' '), $stdin).eval(interpreter)
    end.to output("#{SYNTAX} 'DO' without closing 'LOOP'\n").to_stderr
  end

  it 'loops' do
    interpreter.interpret_line(%w[3 4 5 3 0])
    expect do
      forth_do.eval(interpreter)
    end.to output("0\n[4, 5, 3]\n1\n[5, 3, 4]\n2\n[3, 4, 5]\n").to_stdout
  end

  it 'nests loops' do
    test_do = ForthOps::Do.new(%w[3 0 DO 3 LOOP LOOP], $stdin)
    interpreter.interpret_line(['3', '0', test_do])
    expect(interpreter.stack).to eq [3, 3, 3, 3, 3, 3, 3, 3, 3]
  end
end

describe ForthOps::Begin do
  let(:stdin) { StringIO.new("\n 4 5 + . .\"  HI \" UNTIL") }
  let(:interpreter) { ForthInterpreter.new(stdin) }
  let(:forth_begin) { ForthOps::Begin.new(%w[1 .].join(' '), stdin) }

  it 'reads until until' do
    expect(forth_begin.instance_variable_get(:@block)).to_not include(nil)
    expect(forth_begin.instance_variable_get(:@block)).to_not include('UNTIL')
  end

  it 'errors without until' do
    expect do
      ForthOps::Begin.new(%w[." hi "].join(' '), $stdin).eval(interpreter)
    end.to output("#{SYNTAX} 'BEGIN' without closing 'UNTIL'\n").to_stderr
  end

  it 'loops' do
    interpreter.interpret_line(%w[3 4 5 0 0 0])
    expect do
      forth_begin.eval(interpreter)
    end.to output('1 9 HI 1 9 HI 1 9 HI 1 9 HI ').to_stdout
  end
end

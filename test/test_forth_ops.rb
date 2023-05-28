# frozen_string_literal: true

require 'rspec/autorun'
require 'forthrb'

describe ForthOps::Rot do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }
  subject { ForthOps::Rot.new(nil, nil) }

  it 'rotates the top 3 stack elements' do
    interpreter.interpret_line(%w[1 2 3])
    subject.eval(interpreter)
    expect(interpreter.stack).to eq [2, 3, 1]
  end

  it 'raises a stack underflow error' do
    expect do
      subject.eval(interpreter)
    end.to output(format("#{STACK_UNDERFLOW}\n", have: 0, need: 3)).to_stderr

    interpreter.interpret_line(%w[1])
    expect do
      subject.eval(interpreter)
    end.to output(format("#{STACK_UNDERFLOW}\n", have: 1, need: 3)).to_stderr
  end
end

describe ForthOps::Swap do
  subject { ForthOps::Swap.new(nil, nil) }
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }

  it 'swaps the top 2 stack elements' do
    interpreter.interpret_line(%w[1 2 3])
    subject.eval(interpreter)
    expect(interpreter.stack).to eq [1, 3, 2]
  end

  it 'raises a stack underflow error' do
    expect do
      subject.eval(interpreter)
    end.to output(format("#{STACK_UNDERFLOW}\n", have: 0, need: 2)).to_stderr

    expect do
      interpreter.interpret_line(%w[1])
      subject.eval(interpreter)
    end.to output(format("#{STACK_UNDERFLOW}\n", have: 1, need: 2)).to_stderr
  end
end

describe ForthOps::Variable do
  let(:stdin) { StringIO.new("1 2 3\n") }
  let(:interpreter) { ForthRB::ForthInterpreter.new(stdin) }

  it 'creates a variable' do
    interpreter.interpret_line(String.new('variable test test'))
    expect(interpreter.stack).to eq [1000]
  end

  it 'errors without a name' do
    variable = ForthOps::Variable.new(%w[], StringIO.new)
    expect do
      variable.eval(interpreter)
    end.to output(format(BAD_DEF, msg: "Empty variable definition\n")).to_stderr
  end

  it 'doesn\'t overwrite an existing variable' do
    interpreter.interpret_line(String.new('variable test'))
    expect do
      interpreter.interpret_line(%w[variable test])
    end.to output(format(BAD_DEF, msg: "'test' is already defined\n")).to_stderr
  end
end

describe ForthOps::SetVar do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }
  subject { ForthOps::SetVar.new(nil, nil) }

  it 'sets a variable' do
    interpreter.interpret_line(String.new('variable test 100 test ! test @'))
    expect(interpreter.stack).to eq [100]
  end

  it 'errors for invalid addresses' do
    expect do
      interpreter.interpret_line(String.new('100 1000'))
      subject.eval(interpreter)
    end.to output(format("#{BAD_ADDRESS}\n", address: 1000)).to_stderr

    expect do
      interpreter.interpret_line(String.new('100 5'))
      subject.eval(interpreter)
    end.to output(format("#{BAD_ADDRESS}\n", address: 5)).to_stderr
  end

  it 'raises a stack underflow error' do
    expect do
      subject.eval(interpreter)
    end.to output(format("#{STACK_UNDERFLOW}\n", have: 0, need: 2)).to_stderr

    expect do
      interpreter.interpret_line(String.new('100'))
      subject.eval(interpreter)
    end.to output(format("#{STACK_UNDERFLOW}\n", have: 1, need: 2)).to_stderr
  end
end

describe ForthOps::GetVar do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }
  subject { ForthOps::GetVar.new(nil, nil) }

  it 'gets a variable' do
    interpreter.interpret_line(String.new('variable test 100 test !'))
    interpreter.interpret_line(String.new('test'))
    subject.eval(interpreter)
    expect(interpreter.stack).to eq [100]
  end

  it 'errors for invalid addresses' do
    expect do
      interpreter.interpret_line(String.new('1001 @'))
    end.to output(format("#{BAD_ADDRESS}\n", address: 1001)).to_stderr

    expect do
      interpreter.interpret_line(String.new('5 @'))
    end.to output(format("#{BAD_ADDRESS}\n", address: 5)).to_stderr
  end

  it 'raises a stack underflow error' do
    expect do
      subject.eval(interpreter)
    end.to output(format("#{STACK_UNDERFLOW}\n", have: 0, need: 1)).to_stderr
  end
end

describe ForthOps::Constant do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }

  it 'creates a constant' do
    interpreter.interpret_line(String.new('100 constant test test'))
    expect(interpreter.stack).to eq [100]
  end

  it 'errors without a name' do
    expect do
      interpreter.interpret_line(String.new('100 constant'))
    end.to output(format(BAD_DEF, msg: "Empty constant definition\n")).to_stderr
  end

  it 'doesn\'t overwrite an existing constant' do
    interpreter.interpret_line(String.new('100 constant test'))
    expect do
      interpreter.interpret_line(String.new('100 constant test'))
    end.to output(format(BAD_DEF, msg: "'test' is already defined\n")).to_stderr
  end
end

describe ForthOps::Comment do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }

  it 'ignores a comment' do
    test_comment = ForthOps::Comment.new(String.new('hello world )'), StringIO.new)
    expect do
      test_comment.eval(interpreter)
    end.to_not output.to_stdout
  end

  it 'errors without end parenthesis' do
    test_comment = ForthOps::Comment.new(%w[hello world].join(' '), StringIO.new)
    expect do
      test_comment.eval(interpreter)
    end.to output(format("#{SYNTAX}\n", have: '(', need: ')')).to_stderr
  end

  it 'reads more lines' do
    test_stdin = StringIO.new("hello world )\n")
    ForthOps::Comment.new(%w[hello world].join(' '), test_stdin)
    expect(test_stdin.eof?).to be true
  end
end

describe ForthOps::If do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }
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
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }

  it 'does nothing with false and no else' do
    expect do
      interpreter.interpret_line('0 if 3 . then'.+@)
    end.to_not output.to_stdout
  end

  it 'nests ifs' do
    expect do
      interpreter.interpret_line(%w[1])
      ForthOps::If.new(%w[1 if 4 . else 3 . then then], StringIO.new).eval(interpreter)
    end.to output('4').to_stdout
  end
end

describe ForthOps::Do do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }
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
      ForthOps::Do.new(%w[." hi "].join(' '), StringIO.new).eval(interpreter)
    end.to output(format("#{SYNTAX}\n", have: 'DO', need: 'LOOP')).to_stderr
  end

  it 'loops' do
    interpreter.interpret_line(%w[3 4 5 3 0])
    expect do
      forth_do.eval(interpreter)
    end.to output("0\n[4, 5, 3]\n1\n[5, 3, 4]\n2\n[3, 4, 5]\n").to_stdout
  end

  it 'nests loops' do
    test_do = ForthOps::Do.new(%w[3 0 DO 3 LOOP LOOP], StringIO.new)
    interpreter.interpret_line(['3', '0', test_do])
    expect(interpreter.stack).to eq [3, 3, 3, 3, 3, 3, 3, 3, 3]
  end
end

describe ForthOps::Do do
  let(:interpreter) { ForthRB::ForthInterpreter.new(StringIO.new) }
  let(:forth_do) { ForthOps::Do.new(%w[I .].join(' '), StringIO.new("\nrot dump\nloop 3 4")) }

  it 'errors for invalid loop ranges' do
    expect do
      interpreter.interpret_line(%w[0 3].join(' '))
      forth_do.eval(interpreter)
    end.to output(format("#{BAD_LOOP}\n", start: 3, end: 0)).to_stderr
  end
end

describe ForthOps::Begin do
  let(:stdin) { StringIO.new("\n 4 5 + . .\"  HI \" UNTIL") }
  let(:interpreter) { ForthRB::ForthInterpreter.new(stdin) }
  let(:forth_begin) { ForthOps::Begin.new(%w[1 .].join(' '), stdin) }

  it 'reads until until' do
    expect(forth_begin.instance_variable_get(:@block)).to_not include(nil)
    expect(forth_begin.instance_variable_get(:@block)).to_not include('UNTIL')
  end

  it 'errors without until' do
    expect do
      ForthOps::Begin.new(%w[." hi "].join(' '), StringIO.new).eval(interpreter)
    end.to output(format("#{SYNTAX}\n", have: 'BEGIN', need: 'UNTIL')).to_stderr
  end

  it 'loops' do
    interpreter.interpret_line(%w[3 4 5 0 0 0])
    expect do
      forth_begin.eval(interpreter)
    end.to output('1 9 HI 1 9 HI 1 9 HI 1 9 HI ').to_stdout
  end
end

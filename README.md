# ForthRB
A Forth interpreter written in Ruby.

## Supported Operations
- All standard keywords (`DUMP`, `DROP`, `INVERT`, `ROT`, etc.)
- `( Comments )` and `." strings "`
- Word definitions with `:` and `;`
- `IF ... ELSE ... THEN` blocks
- `DO ... LOOP` blocks
- `BEGIN ... UNTIL` blocks
- Variables (`VARIABLE`, `CONSTANT`, `!`, `@`, `ALLOT`, `CELLS`)

## Installing
The interpreter can be installed by building and installing with gem:

    gem build forthrb.gemspec
    gem install forthrb-xxx.gem


## Running
The interpreter can be started by calling `forthrb` with no arguments.  
When given an argument, it is assumed to be a filename and the interpreter
will be run on the input file.

Additionally, within the interpreter the command `:: filename` will attempt
to load a file called `filename` in the current directory. 

## Notes
The interpreter does not do any syntax checking during word definitions,
or inside IF statements. This is deferred until they are evaluated. This
allows for recursive word definitions, as the interpreter will not fail
on unknown words inside a word definition.  

For example:

    : fac DUP 1 > IF DUP 1 - fac * ELSE DROP 1 THEN ;
    5 fac .
    120 ok

Memory addresses for variables start at 1000.

Also, the CELLS keyword doesn't do anything in this implementation because
the cell size is always 1, so there is nothing to multiply.

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

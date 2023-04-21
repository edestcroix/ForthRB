# ForthRB
A (work in progress) Forth interpreter written in Ruby.

## Supported Operations
- All standard keywords (`DUMP`, `DROP`, `INVERT`, `ROT`, etc.)
- `( Comments )` and `." strings "`
- Word definitions with `:` and `;`
- `IF ELSE THEN` blocks
- `DO LOOP` blocks

## To Be Implemented
- `BEGIN` loops.
- Variables.
- Better error handling and syntax checking.

## Notes
The interpreter does not do any syntax checking during word definitions,
or inside IF statements. This is deferred until they are evaluated. This
allows for recursive word definitions, as the interpreter will not fail
on unknown words inside a word definition.  

For example:

    : fac DUP 1 > IF DUP 1 - fac * ELSE DROP 1 THEN ;
    5 fac .
    120 ok


Also, any forms of nested IF and DO statements should theoretically work,
but this hasn't been tested yet.

The code is also a complete mess. Probably going to redo some of it. Maybe.

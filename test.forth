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
23 eggsize
: faci 1 SWAP 1 + 1 DO I * LOOP ;
5 faci .
: fac ( n1 -- n2 ) DUP 1 > ( recursive factorial )
IF DUP 1 - fac *
ELSE DROP 1 THEN
;
5 fac .
( Testing Variables )
: ? @ . ;

VARIABLE numbers 3 CELLS ALLOT
( array of size 4 )
10 numbers 0 CELLS + !
20 numbers 1 CELLS + !
30 numbers 2 CELLS + !
40 numbers 3 CELLS + !
2 CELLS numbers + ?
3 CONSTANT third
third CELLS numbers + ?

3 0 DO 3 0 DO  3 . LOOP LOOP

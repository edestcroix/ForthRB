(* Forth Interpreter *)



(*
 TODO:
   - Better formatted output
   - Some operations are not implemented (CR, maybe others)
   - ." and " are not implemented yet.
   - Word definitions
   - Control flows, variables, comments etc.


   NOTE:
     - Probably going to have to set up some form
     of environment for variables, control flows etc.
     Need closures and such.
 *)


type 'a stack = 'a list

type stack_result = 
  | Ok of int stack
  | Error of string

let stack_error = Error "Stack Underflow"
let cmd_error = Error "Invalid Command"

type forth_command = 
  | Push of int
  | Add | Subtract | Multiply | Divide
  | Dup | Drop | Dump
  | Swap | Over | Invert | Rot
  | Emit | Emit_Ascii | Cr
  | Eq | Lt | Gt
  | And | Or | Xor
  (* TODO: Handle words  *)
  | StrLQ | StrRQ
  | Quit
  | Error of string
;;

let parse (s : string) : forth_command =
  match s with
  | "+" -> Add
  | "-" -> Subtract
  | "*" -> Multiply
  | "/" -> Divide
  | "dup" | "DUP" -> Dup
  | "drop" | "DROP" -> Drop
  | "swap" | "SWAP" -> Swap
  | "over" | "OVER" -> Over
  | "dump" | "DUMP" -> Dump
  | "quit" | "QUIT" -> Quit
  | "invert" | "INVERT"-> Invert
  | "rot" | "ROT" -> Rot
  | "emit" | "EMIT" -> Emit_Ascii
  | "." -> Emit
  | "cr" | "CR" -> Cr
  | "=" -> Eq
  | "<" -> Lt
  | ">" -> Gt
  | "and" | "AND" -> And
  | "or"  | "OR"-> Or
  | "xor" | "XOR" -> Xor
  | ".\"" -> StrLQ
  | "\"" -> StrRQ
  | _ -> try Push (int_of_string s) with _ -> Error "invalid command"

;;

let op1 f s =
  match s with
  | _ :: _ -> Ok (f s)
  | _ -> stack_error
;;


let op2 f s =
  match s with
  | x :: y :: s' -> Ok (f x y :: s')
  | _ -> stack_error
;;

let print_stack (s : int stack) : string =
  print_string "[" ;
  let rec print_stack' (s : int stack) : string =
    match s with
    | [] -> ""
    | x :: [] -> (string_of_int x) ^ "]"
    | x :: s' -> (string_of_int x) ^ " " ^ (print_stack' s')
  in print_stack' s
;;

let eval s c : stack_result =
  match c with
  | Push i   -> print_int i; print_char(' ');Ok (i :: s)
  | Add      -> op2 (+) s
  | Subtract -> op2 (-) s
  | Multiply -> op2 ( * ) s
  | Divide   -> op2 (/) s
  | Dup      -> op1 (fun s -> (List.hd s) :: s) s
  | Drop     -> op1 (List.tl) s
  | Dump -> (print_string (print_stack s); print_newline();Ok s)
  | Swap     -> (match s with
      | [] | [_] -> stack_error
      | x :: y :: s' -> Ok(y :: x :: s'))
  | Over -> (match s with
    | x :: y :: s' -> Ok(x :: y :: x :: s')
    | _ -> stack_error )
  | Invert -> (match s with
    | x :: s' -> Ok((-x) :: s')
    | _ -> stack_error)
  | Rot -> (match s with
    | x :: y :: z :: s' -> Ok(y :: z :: x :: s')
    | _ -> stack_error)
  | Emit -> (match s with 
    [] -> stack_error
    | x :: s' -> (print_int x); print_char(' '); Ok(s'))
| Emit_Ascii -> (match s with 
    [] -> stack_error
    | x :: s' -> (print_char (char_of_int x)); Ok(s'))
  | Eq  -> op2 (fun x y -> if x = y then -1 else 0) s
  | Lt  -> op2 (fun x y -> if y < x then -1 else 0) s
  | Gt  -> op2 (fun x y -> if y > x then -1 else 0) s
  | And -> op2 (land) s
  | Or  -> op2 (lor) s
  | Xor -> op2 (lxor) s
  | Error e -> Error e
  | _ -> cmd_error
;;

let rec eval_input input stack =
  match input with
  | [] -> Ok stack
  | x :: xs -> 
    let c = parse x in
    match eval stack c with
    | Ok s -> eval_input xs s
    | Error e -> Error e
;;

let parse_input s =
  let len = String.length s in
  let rec parse_input' (s : string) (i : int) (acc : string) : string list =
    if i = len then
      acc :: []
    else
      let c = s.[i] in
      if c = ' ' then
        acc :: parse_input' s (i + 1) ""
      else
        parse_input' s (i + 1) (acc ^ (String.make 1 c))
  in
  parse_input' s 0 ""
;;

let stack = [] in
let rec loop (stack : int stack) : unit =
  print_string "input: ";
  let s = String.trim (read_line ()) in
  if s = "quit" then () else
  match eval_input (parse_input s) stack with
  | Ok s -> print_string "ok"; print_newline (); loop s
  | Error e -> print_string "error: "; print_string e; print_newline (); loop stack
in loop stack



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
  | WordStart | WordEnd
  | Quit
  | Keyword of string
  | Error of string
;;

type forth_word = 
  | Word of string * forth_command list

type env = forth_word list

type stack_result = 
  | Ok of int stack
  | Error of string

let stack_error = Error "Stack Underflow"
let cmd_error = Error "Invalid Command"


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
  | ":" -> WordStart
  | ";" -> WordEnd
  | "if" | "IF" -> If []
  | _ -> try Push (int_of_string s) with _ -> Keyword s

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


let rec eval s c env : stack_result =
  let rec env_lookup (env : env) (s : string) : forth_command list =
    match env with
    | [] -> []
    | Word (name, cmd) :: env' -> if name = s then cmd else env_lookup env' s
  in
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
  | Keyword key -> (match env_lookup env key with
    | [] -> Error "Word not found"
    | x :: _ -> eval s x env)
  | _ -> cmd_error
;;


(* TODO: read_word *)

let read_word _ = failwith "not implemented"


let rec read_in (s : int stack) (env : env) : unit =
  print_string ">> ";
  let line = read_line () in
  if line = "quit" then exit 0;
  let words = String.split_on_char ' ' line in
  let rec read_in' (s : int stack) (env : env) (words : string list) : unit =
    match words with
    | [] -> print_string "ok\n"; read_in s env
    | x :: xs -> (match parse x with
      | Error e -> print_string e; print_newline(); read_in s env
      | WordStart -> read_in s (read_word env)
      | _ -> (match eval s (parse x) env with
        | Ok s' -> read_in' s' env xs
        | Error e -> print_string e; print_newline(); read_in s env))
  in read_in' s env words
;;

read_in [] [];;

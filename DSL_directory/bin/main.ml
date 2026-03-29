open My_utils
open Tokenizer

let source_game = read_file "./source-code/abc.agen"

let () =
  let tokens = tokenize (explode source_game) in
  print_endline (print_tokens tokens)
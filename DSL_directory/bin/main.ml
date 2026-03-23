open Dsl_directory
open My_utils
open Tokenizer
let source_game = read_file "./source-code/abc.agen"
let () =
let tokens = tokenize (explode source_game) in
let tokens_as_str = print_tokens tokens in
 print_endline tokens_as_str;
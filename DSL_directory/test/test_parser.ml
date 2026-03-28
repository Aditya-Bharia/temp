let () =
  let tokens = Tokenizer.tokenize "automaton" in
  let ast = Parser.parse_program tokens in
  if ast = [] then failwith "parser test failed" else print_endline "parser test passed"
;;

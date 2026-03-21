open Types

let () =
  let input = "automaton demo { state q0 }" in
  let tokens = Tokenizer.tokenize input in
  let program = Parser.parse_program tokens in
  match Validator.validate_program program with
  | Ok () -> print_endline (Interpreter.run program)
  | Error msg -> prerr_endline ("Validation error: " ^ msg)

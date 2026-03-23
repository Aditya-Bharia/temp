open Types

let () =
  let tokens = Tokenizer.tokenize "automaton" in
  match List.hd tokens with
  | Token.Automaton -> print_endline "tokenizer test passed"
  | _ -> failwith "tokenizer test failed"

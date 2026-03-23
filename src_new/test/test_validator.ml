open Types

let () =
  let a = { name = "dfa"; states = [ "q0" ]; transitions = [] } in
  match Validator.validate_automaton a with
  | Ok () -> print_endline "validator test passed"
  | Error e -> failwith e

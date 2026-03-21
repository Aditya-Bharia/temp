open Types

let validate_automaton (a : automaton) : (unit, string) result =
  if String.length a.name = 0 then Error "Automaton name cannot be empty"
  else if a.states = [] then Error "Automaton must declare at least one state"
  else Ok ()

let validate_program (p : program) : (unit, string) result =
  let rec loop = function
    | [] -> Ok ()
    | x :: xs -> (
        match validate_automaton x with
        | Ok () -> loop xs
        | Error e -> Error e)
  in
  loop p

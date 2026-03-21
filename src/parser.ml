open Types

let parse_program (tokens : Token.t list) : program =
  match tokens with
  | [] -> []
  | _ ->
      [ {
          name = "placeholder";
          states = [ "q0" ];
          transitions = [ { src = "q0"; symbol = "a"; dst = "q0" } ];
        } ]

open Types

let tokenize (input : string) : Token.t list =
  let words =
    input
    |> String.split_on_char ' '
    |> List.filter (fun w -> String.length w > 0)
  in
  let to_token = function
    | "automaton" -> Token.Automaton
    | "state" -> Token.State
    | "->" -> Token.Arrow
    | "{" -> Token.LBrace
    | "}" -> Token.RBrace
    | x -> Token.Identifier x
  in
  List.map to_token words @ [ Token.Eof ]

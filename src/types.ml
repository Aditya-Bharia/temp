(module Token = struct
  type t =
    | Automaton
    | State
    | Arrow
    | LBrace
    | RBrace
    | Identifier of string
    | Eof
end)

type transition = {
  src : string;
  symbol : string;
  dst : string;
}

type automaton = {
  name : string;
  states : string list;
  transitions : transition list;
}

type program = automaton list

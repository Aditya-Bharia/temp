(* ===================================================
   PART 1 : binary operators
   =================================================== *)

type bin_op =
  | Add
  | Sub
  | Mul
  | Div
  | Eq
  | Neq
  | Lt
  | Gt
  | Leq
  | Geq
  | And
  | Or


(* ===================================================
   PART 2 : expressions
   =================================================== *)

type expr =

  (* basic values *)
  | Num    of int
  | Str    of string
  | Bool   of bool
  | Var    of string

  (* operators *)
  | BinOp  of bin_op * expr * expr
  | NotOp  of expr
  | Neg    of expr             

  (* assignment is an expression: x = expr *)
  | Assign of string * expr

  (* user defined function call *)
  | Call   of string * expr list

  (* list literal and index access *)
  | List   of expr list
  | Index  of expr * expr      (* expr[expr] *)

  (* language operations *)
  | Union        of expr * expr
  | Intersection of expr * expr
  | Difference   of expr * expr
  | Complement   of expr
  | ConcatLang   of expr * expr
  | KleeneStar   of expr
  | KleenePlus   of expr
  | ReverseLang  of expr

  (* transformations *)
  | Determinize  of expr
  | Minimize     of expr
  | RegexToNfa   of expr
  | NfaToRegex   of expr
  | DfaToRegex   of expr

  (* analysis functions, all args are expr now *)
  | Accepts         of expr * expr
  | Trace           of expr * expr
  | Equivalent      of expr * expr
  | RegexEquivalent of expr * expr
  | Validate        of expr
  | Subset          of expr * expr
  | IsEmpty         of expr
  | IsFinite        of expr
  | IsMinimal       of expr
  | IsDeterministic of expr
  | Reachable       of expr
  | DeadStates      of expr

  (* string operations *)
  | StrReverse of expr
  | StrConcat  of expr * expr
  | Chars      of expr
  | RandomStr  of expr * expr   

  (* import returns a value so it lives in expr *)
  | Import of string


(* ===================================================
   PART 3 : automaton body
   =================================================== *)

(* one transition entry inside the transition block *)
type transition_rule = {
  from_s : string;
  symbol : string option;   (* None for epsilon *)
  to_s   : string;
}

(* transition block holds all rules together as a list *)
type automaton_body_item =
  | States      of string list
  | Alphabet    of string list
  | StartState  of string
  | FinalState  of string list
  | Transitions of transition_rule list  

type automaton_type = NFA | DFA

type automaton_def = {
  auto_type : automaton_type;
  auto_name : string;
  body      : automaton_body_item list;
}


(* ===================================================
   PART 4 : statements
   =================================================== *)

type stmt =

  | VarDecl   of string * expr

  | FnDecl    of string * string list * stmt list

  | AutoDecl  of automaton_def

  (* else list is empty when there is no else branch *)
  | If        of expr * stmt list * stmt list

  | While     of expr * stmt list

  | For       of string * expr * stmt list

  | Break

  | Continue

  (* return expr? -- expr is optional, None means bare return *)
  | Return    of expr option

  | Print     of expr

  | Visualize of expr

  | Table     of expr

  | Stats     of expr

  | Export    of expr * string

  | Append    of expr * expr
  | Remove    of expr * expr 

  (* any expression written as a standalone statement *)
  | ExprStmt  of expr


(* ===================================================
   PART 5 : program
   a program is just a flat list of statements
   =================================================== *)

type program = stmt list
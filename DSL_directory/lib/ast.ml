(* ast.ml — Abstract Syntax Tree for AutomataGen DSL *)

(* ── Source position ─────────────────────────────────────────────────────── *)
(* Every node that can produce a name-resolution error carries a pos so
   check.ml can report the exact line and column. *)

type pos = { line : int; col : int }

let dummy_pos = { line = 0; col = 0 }

(* ── Operators ───────────────────────────────────────────────────────────── *)

type binop =
  | Add | Sub | Mul | Div          (* arithmetic        *)
  | Eq  | Neq                      (* equality          *)
  | Lt  | Gt  | Leq | Geq          (* comparison        *)
  | And_placeholder                 (* logical and       *)
  | Or_placeholder                  (* logical or        *)

type unop =
  | Neg   (* unary minus  *)
  | Not   (* logical not  *)

(* ── Automaton kind ──────────────────────────────────────────────────────── *)

type automaton_kind = NFA | DFA

(* ── Expressions ─────────────────────────────────────────────────────────── *)

type expr =
  (* ── Literals ── *)
  | IntLit    of int                          (* 42              *)
  | StrLit    of string                       (* "hello"         *)
  | BoolLit   of bool                         (* true / false    *)
  | ListLit   of expr list                    (* [ e1, e2, ... ] *)

  (* ── Names ── *)
  | Var       of string * pos                 (* x               *)

  (* ── Operators ── *)
  | Binop     of binop * expr * expr          (* a + b           *)
  | Unop      of unop  * expr                 (* -x  /  not b    *)

  (* ── Assignment (expression-level) ── *)
  | Assign    of string * expr * pos          (* x = expr        *)

  (* ── Index and call ── *)
  | Index     of expr * expr                  (* xs[i]           *)
  | Call      of expr * expr list             (* f(a, b)         *)

  (* ── Import ── *)
  | Import    of string * pos                 (* import("m.json")*)

  (* ── Language operations (return a new automaton) ── *)
  | Union         of expr * expr              (* union(A, B)     *)
  | Intersection  of expr * expr              (* intersection(A,B)*)
  | Difference    of expr * expr              (* difference(A,B) *)
  | Complement    of expr * pos               (* complement(A)   *)
  | ConcatLang    of expr * expr              (* concat_lang(A,B)*)
  | KleeneStar    of expr                     (* kleene_star(A)  *)
  | KleenePlus    of expr                     (* kleene_plus(A)  *)
  | ReverseLang   of expr                     (* reverse_lang(A) *)

  (* ── Transformations (return an automaton) ── *)
  | Determinize   of expr                     (* determinize(M)  *)
  | Minimize      of expr                     (* minimize(M)     *)
  | RegexToNfa    of expr                     (* regex_to_nfa(r) *)
  | NfaToRegex    of expr                     (* nfa_to_regex(M) *)
  | DfaToRegex    of expr * pos               (* dfa_to_regex(D) *)

  (* ── Analysis (return bool / string / list) ── *)
  | Accepts       of expr * expr              (* accepts(M, s)   *)
  | Trace         of expr * expr              (* trace(M, s)     *)
  | Equivalent    of expr * expr              (* equivalent(A,B) *)
  | RegexEquiv    of expr * expr              (* regex_equivalent*)
  | Validate      of expr                     (* validate(M)     *)
  | Subset        of expr * expr              (* subset(A, B)    *)
  | IsEmpty       of expr                     (* is_empty(A)     *)
  | IsFinite      of expr                     (* is_finite(A)    *)
  | IsMinimal     of expr * pos               (* is_minimal(D)   *)
  | IsDeterministic of expr                   (* is_deterministic*)
  | Reachable     of expr                     (* reachable(A)    *)
  | DeadStates    of expr                     (* dead_states(A)  *)

  (* ── String operations ── *)
  | Reverse       of expr                     (* reverse(s)      *)
  | ConcatStr     of expr * expr              (* concat(s1, s2)  *)
  | Chars         of expr                     (* chars(s)        *)
  | RandomStr     of expr * expr              (* random_str(n,ab)*)

(* ── Transition entry inside an automaton body ──────────────────────────── *)

type symbol =
  | Sym of string    (* a named symbol from the alphabet *)
  | Eps              (* epsilon transition               *)

type trans_entry = {
  from_state : string;
  on_symbol  : symbol;
  to_state   : string;
  pos        : pos;
}

(* ── Automaton body ──────────────────────────────────────────────────────── *)

type automaton_body = {
  kind         : automaton_kind;
  name         : string;
  states       : string list;
  alphabet     : string list;
  start        : string;
  final_states : string list;
  transitions  : trans_entry list;
  pos          : pos;     (* position of the NFA/DFA keyword *)
}

(* ── Statements ──────────────────────────────────────────────────────────── *)

type stmt =
  | VarDecl     of string * expr * pos
  (* var x = expr *)

  | FnDecl      of string * string list * stmt list * pos
  (* fn name(p1, p2) { body } *)

  | AutomatonDecl of automaton_body
  (* NFA M { ... }  /  DFA D { ... } *)

  | If          of expr * stmt list * stmt list option * pos
  (* if cond { then_body } (else { else_body })? *)

  | While       of expr * stmt list * pos
  (* while cond { body } *)

  | For         of string * expr * stmt list * pos
  (* for x in iterable { body } *)

  | Return      of expr option * pos
  (* return expr? *)

  | Break       of pos
  (* break *)

  | Continue    of pos
  (* continue *)

  | Print       of expr * pos
  (* print(expr) *)

  | Visualize   of expr * pos
  (* visualize(expr) *)

  | Table       of expr * pos
  (* table(expr) *)

  | Stats       of expr * pos
  (* stats(expr) *)

  | Export      of expr * string * pos
  (* export(M, "file.png") *)

  | Append      of expr * expr * pos
  (* append(xs, v) *)

  | Remove      of expr * expr * pos
  (* remove(xs, i) *)

  | ExprStmt    of expr
  (* bare expression used as a statement, e.g. a function call *)

(* ── Top-level program ───────────────────────────────────────────────────── *)

type program = stmt list
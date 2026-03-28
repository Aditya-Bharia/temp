open Ast

(* helpers *)
(* indent depth  →  "    " repeated depth times (4 spaces per level) *)
let indent (depth : int) : string = String.make (depth * 4) ' '

(* wrap a string in double quotes and escape any special characters.
   e.g.  hello "world"  →  "hello \"world\""                        *)
let quoted (s : string) : string = Printf.sprintf "\"%s\"" (String.escaped s)

(* emit a Python list of quoted strings.
   e.g.  ["q0"; "q1"; "q2"]  →  ["q0", "q1", "q2"]                 *)
let py_str_list (items : string list) : string =
  "[" ^ String.concat ", " (List.map quoted items) ^ "]"
;;

(* emit a Python list of arbitrary already emitted expressions.    *)
let py_expr_list (items : string list) : string = "[" ^ String.concat ", " items ^ "]"

let rec emit_expr (e : expr) : string =
  match e with
  (* literals *)
  | Num n -> string_of_int n
  | Str s -> quoted s
  | Bool b -> if b then "True" else "False"
  (* variable reference *)
  | Var x -> x
  (* binary operators *)
  | BinOp (op, left, right) ->
    let l = emit_expr left in
    let r = emit_expr right in
    let op_str =
      match op with
      | Add -> "+"
      | Sub -> "-"
      | Mul -> "*"
      | Div -> "//"
      | Eq -> "=="
      | Neq -> "!="
      | Lt -> "<"
      | Gt -> ">"
      | Leq -> "<="
      | Geq -> ">="
      | And -> "and"
      | Or -> "or"
    in
    Printf.sprintf "(%s %s %s)" l op_str r
  (* unary operators *)
  | NotOp e -> Printf.sprintf "(not %s)" (emit_expr e)
  | Neg e -> Printf.sprintf "(-%s)" (emit_expr e)
  (* assignment expression: emit the Python 3.8+ walrus operator  (x := v). *)
  | Assign (x, e) -> Printf.sprintf "(%s := %s)" x (emit_expr e)
  (* user defined function call *)
  | Call (fname, args) ->
    let arg_strs = List.map emit_expr args in
    Printf.sprintf "%s(%s)" fname (String.concat ", " arg_strs)
  (* list literal *)
  | List elems -> py_expr_list (List.map emit_expr elems)
  (* index access *)
  | Index (collection, idx) ->
    Printf.sprintf "%s[%s]" (emit_expr collection) (emit_expr idx)
  (* language operations *)
  | Union (a, b) -> Printf.sprintf "union(%s, %s)" (emit_expr a) (emit_expr b)
  | Intersection (a, b) ->
    Printf.sprintf "intersection(%s, %s)" (emit_expr a) (emit_expr b)
  | Difference (a, b) -> Printf.sprintf "difference(%s, %s)" (emit_expr a) (emit_expr b)
  | Complement a -> Printf.sprintf "complement(%s)" (emit_expr a)
  | ConcatLang (a, b) -> Printf.sprintf "concat_lang(%s, %s)" (emit_expr a) (emit_expr b)
  | KleeneStar a -> Printf.sprintf "kleene_star(%s)" (emit_expr a)
  | KleenePlus a -> Printf.sprintf "kleene_plus(%s)" (emit_expr a)
  | ReverseLang a -> Printf.sprintf "reverse_lang(%s)" (emit_expr a)
  (* transformations *)
  | Determinize a -> Printf.sprintf "determinize(%s)" (emit_expr a)
  | Minimize a -> Printf.sprintf "minimize(%s)" (emit_expr a)
  | RegexToNfa a -> Printf.sprintf "regex_to_nfa(%s)" (emit_expr a)
  | NfaToRegex a -> Printf.sprintf "nfa_to_regex(%s)" (emit_expr a)
  | DfaToRegex a -> Printf.sprintf "dfa_to_regex(%s)" (emit_expr a)
  (*analysis functions*)
  | Accepts (m, s) -> Printf.sprintf "accepts(%s, %s)" (emit_expr m) (emit_expr s)
  | Trace (m, s) -> Printf.sprintf "trace(%s, %s)" (emit_expr m) (emit_expr s)
  | Equivalent (a, b) -> Printf.sprintf "equivalent(%s, %s)" (emit_expr a) (emit_expr b)
  | RegexEquivalent (a, b) ->
    Printf.sprintf "regex_equivalent(%s, %s)" (emit_expr a) (emit_expr b)
  | Validate a -> Printf.sprintf "validate(%s)" (emit_expr a)
  | Subset (a, b) -> Printf.sprintf "subset(%s, %s)" (emit_expr a) (emit_expr b)
  | IsEmpty a -> Printf.sprintf "is_empty(%s)" (emit_expr a)
  | IsFinite a -> Printf.sprintf "is_finite(%s)" (emit_expr a)
  | IsMinimal a -> Printf.sprintf "is_minimal(%s)" (emit_expr a)
  | IsDeterministic a -> Printf.sprintf "is_deterministic(%s)" (emit_expr a)
  | Reachable a -> Printf.sprintf "reachable(%s)" (emit_expr a)
  | DeadStates a -> Printf.sprintf "dead_states(%s)" (emit_expr a)
  (*string operations*)
  | StrReverse a -> Printf.sprintf "str_reverse(%s)" (emit_expr a)
  | StrConcat (a, b) -> Printf.sprintf "str_concat(%s, %s)" (emit_expr a) (emit_expr b)
  | Chars a -> Printf.sprintf "chars(%s)" (emit_expr a)
  | RandomStr (n, a) -> Printf.sprintf "random_str(%s, %s)" (emit_expr n) (emit_expr a)
  | Import path -> Printf.sprintf "import_automaton(%s)" (quoted path)

(* this transition also dict groups all rules by (from_state, symbol), so that non-deterministic transitions like
   q0 a -> q0,   q0 a -> q1 become the single entry: "q0": {"a": ["q0", "q1"]} *)
and emit_automaton_def (d : automaton_def) : string =
  let states = ref [] in
  let alphabet = ref [] in
  let start = ref "" in
  let final = ref [] in
  let trans_rules = ref [] in
  List.iter
    (fun item ->
       match item with
       | States ss -> states := ss
       | Alphabet ss -> alphabet := ss
       | StartState s -> start := s
       | FinalState ss -> final := ss
       | Transitions ts -> trans_rules := ts)
    d.body;
  (* build the transition dictionary. using a list-based association approach to group targets.*)
  let rec assoc_add key value = function
    | [] -> [ key, [ value ] ]
    | (k, vs) :: rest when k = key -> (k, vs @ [ value ]) :: rest
    | hd :: rest -> hd :: assoc_add key value rest
  in
  (* build association list: (from_state, symbol) -> target list *)
  let grouped =
    List.fold_left
      (fun acc (rule : transition_rule) ->
         let sym_str =
           match rule.symbol with
           | Some s -> s (* real symbol, e.g. "a" *)
           | None -> "eps" (* epsilon transition *)
         in
         assoc_add (rule.from_s, sym_str) rule.to_s acc)
      []
      !trans_rules
  in
  let from_states = List.sort_uniq compare (List.map (fun ((fs, _), _) -> fs) grouped) in
  let emit_state_entry fs =
    (* find all (symbol → targets) pairs for this from-state *)
    let sym_entries =
      List.filter_map
        (fun ((s, sym), tgts) ->
           if s = fs
           then
             (* emit:  "a": ["q1", "q2"] *)
             Some (Printf.sprintf "%s: %s" (quoted sym) (py_str_list tgts))
           else None)
        grouped
    in
    (* emit:  "q0": {"a": ["q1"], "b": ["q0"]} *)
    Printf.sprintf "%s: {%s}" (quoted fs) (String.concat ", " sym_entries)
  in
  let trans_dict =
    "{" ^ String.concat ", " (List.map emit_state_entry from_states) ^ "}"
  in
  (*assemble the automaton *)
  let kind_str =
    match d.auto_type with
    | NFA -> "\"NFA\""
    | DFA -> "\"DFA\""
  in
  Printf.sprintf
    "Automaton(%s, %s, %s, %s, %s, %s, %s)"
    kind_str
    (quoted d.auto_name)
    (py_str_list !states)
    (py_str_list !alphabet)
    (quoted !start)
    (py_str_list !final)
    trans_dict

and emit_stmt (depth : int) (s : stmt) : string =
  let ind = indent depth in
  let ind1 = indent (depth + 1) in
  let emit_body stmts =
    match List.map (emit_stmt (depth + 1)) stmts with
    | [] -> [ ind1 ^ "pass" ]
    | lines -> lines
  in
  match s with
  | VarDecl (name, value_expr) ->
    Printf.sprintf "%s%s = %s" ind name (emit_expr value_expr)
  | FnDecl (fname, params, body) ->
    let param_str = String.concat ", " params in
    let header = Printf.sprintf "%sdef %s(%s):" ind fname param_str in
    let body_lines = emit_body body in
    header ^ "\n" ^ String.concat "\n" body_lines
  | AutoDecl auto_def ->
    Printf.sprintf "%s%s = %s" ind auto_def.auto_name (emit_automaton_def auto_def)
  | If (cond, then_body, else_body) ->
    let if_line = Printf.sprintf "%sif %s:" ind (emit_expr cond) in
    let then_lines = emit_body then_body in
    let if_block = if_line ^ "\n" ^ String.concat "\n" then_lines in
    if else_body = []
    then if_block
    else (
      let else_line = Printf.sprintf "%selse:" ind in
      let else_lines = emit_body else_body in
      if_block ^ "\n" ^ else_line ^ "\n" ^ String.concat "\n" else_lines)
  | While (cond, body) ->
    let while_line = Printf.sprintf "%swhile %s:" ind (emit_expr cond) in
    let body_lines = emit_body body in
    while_line ^ "\n" ^ String.concat "\n" body_lines
  | For (loop_var, iterable, body) ->
    let for_line = Printf.sprintf "%sfor %s in %s:" ind loop_var (emit_expr iterable) in
    let body_lines = emit_body body in
    for_line ^ "\n" ^ String.concat "\n" body_lines
  | Break -> ind ^ "break"
  | Continue -> ind ^ "continue"
  | Return None -> ind ^ "return"
  | Return (Some e) -> Printf.sprintf "%sreturn %s" ind (emit_expr e)
  | Print e -> Printf.sprintf "%sdsl_print(%s)" ind (emit_expr e)
  | Visualize e -> Printf.sprintf "%svisualize(%s)" ind (emit_expr e)
  | Table e -> Printf.sprintf "%stable(%s)" ind (emit_expr e)
  | Stats e -> Printf.sprintf "%sstats(%s)" ind (emit_expr e)
  | Export (e, filepath) ->
    Printf.sprintf "%sexport(%s, %s)" ind (emit_expr e) (quoted filepath)
  (*append(xs, v)   →  _append(xs, v)
  remove(xs, i)   →  _remove(xs, i)
  used _append / _remove (with underscore) to avoid shadowing python's built-in list methods. *)
  | Append (lst_expr, val_expr) ->
    Printf.sprintf "%s_append(%s, %s)" ind (emit_expr lst_expr) (emit_expr val_expr)
  | Remove (lst_expr, val_expr) ->
    Printf.sprintf "%s_remove(%s, %s)" ind (emit_expr lst_expr) (emit_expr val_expr)
  (* expression statement *)
  | ExprStmt (Assign (name, value_expr)) ->
    (* assignment as a statement: use plain  x = v  not walrus  x := v *)
    Printf.sprintf "%s%s = %s" ind name (emit_expr value_expr)
  | ExprStmt e -> Printf.sprintf "%s%s" ind (emit_expr e)
;;

(*the function called from main.ml.
  takes the full ast and produces the complete python source file as a string
  the output always starts with: from runtime import *, followed by one python statement per dsl statement, separated by blank lines for readability*)
let emit_program (prog : program) : string =
  let header = "from runtime import *\n\n" in
  let stmt_strings = List.map (emit_stmt 0) prog in
  header ^ String.concat "\n" stmt_strings ^ "\n"
;;

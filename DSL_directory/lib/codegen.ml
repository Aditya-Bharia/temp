open Ast
(* helpers *)
(* indent depth  →  "    " repeated depth times (4 spaces per level) *)
let indent (depth : int) : string = String.make (depth * 4) ' '
(* wrap a string in double quotes and escape any special characters.
   e.g.  hello "world"  →  "hello \"world\""                       *)
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
  | IntLit n -> string_of_int n
  | StrLit s -> quoted s
  | BoolLit b -> if b then "True" else "False"
  (* variable reference *)
  (* Var now carries a pos; we ignore it in codegen *)
  | Var (x, _pos) -> x
  (* binary operators *)
  | Binop (op, left, right) ->
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
      | And_placeholder -> "and"
      | Or_placeholder -> "or"
    in
    Printf.sprintf "(%s %s %s)" l op_str r
  (* unary operators *)
  | Unop (Not, e) -> Printf.sprintf "(not %s)" (emit_expr e)
  | Unop (Neg, e) -> Printf.sprintf "(-%s)" (emit_expr e)
  (* assignment expression: emit the Python 3.8+ walrus operator  (x := v). *)
  | Assign (x, e, _pos) -> Printf.sprintf "(%s := %s)" x (emit_expr e)
  (* user defined function call *)
  | Call (callee, args) ->
    let arg_strs = List.map emit_expr args in
    Printf.sprintf "%s(%s)" (emit_expr callee) (String.concat ", " arg_strs)
  (* list literal *)
  | ListLit elems -> py_expr_list (List.map emit_expr elems)
  (* index access *)
  | Index (collection, idx) ->
    Printf.sprintf "%s[%s]" (emit_expr collection) (emit_expr idx)
  (* language operations *)
  | Union (a, b) -> Printf.sprintf "union(%s, %s)" (emit_expr a) (emit_expr b)
  | Intersection (a, b) ->
    Printf.sprintf "intersection(%s, %s)" (emit_expr a) (emit_expr b)
  | Difference (a, b) -> Printf.sprintf "difference(%s, %s)" (emit_expr a) (emit_expr b)
  | Complement (a, _pos) -> Printf.sprintf "complement(%s)" (emit_expr a)
  | ConcatLang (a, b) -> Printf.sprintf "concat_lang(%s, %s)" (emit_expr a) (emit_expr b)
  | KleeneStar a -> Printf.sprintf "kleene_star(%s)" (emit_expr a)
  | KleenePlus a -> Printf.sprintf "kleene_plus(%s)" (emit_expr a)
  | ReverseLang a -> Printf.sprintf "reverse_lang(%s)" (emit_expr a)
  (* transformations *)
  | Determinize a -> Printf.sprintf "determinize(%s)" (emit_expr a)
  | Minimize a -> Printf.sprintf "minimize(%s)" (emit_expr a)
  | RegexToNfa a -> Printf.sprintf "regex_to_nfa(%s)" (emit_expr a)
  | NfaToRegex a -> Printf.sprintf "nfa_to_regex(%s)" (emit_expr a)
  | DfaToRegex (a, _pos) -> Printf.sprintf "dfa_to_regex(%s)" (emit_expr a)
  (*analysis functions*)
  | Accepts (m, s) -> Printf.sprintf "accepts(%s, %s)" (emit_expr m) (emit_expr s)
  | Trace (m, s) -> Printf.sprintf "trace(%s, %s)" (emit_expr m) (emit_expr s)
  | Equivalent (a, b) -> Printf.sprintf "equivalent(%s, %s)" (emit_expr a) (emit_expr b)
  | RegexEquiv (a, b) ->
    Printf.sprintf "regex_equivalent(%s, %s)" (emit_expr a) (emit_expr b)
  | Validate a -> Printf.sprintf "validate(%s)" (emit_expr a)
  | Subset (a, b) -> Printf.sprintf "subset(%s, %s)" (emit_expr a) (emit_expr b)
  | IsEmpty a -> Printf.sprintf "is_empty(%s)" (emit_expr a)
  | IsFinite a -> Printf.sprintf "is_finite(%s)" (emit_expr a)
  | IsMinimal (a, _pos) -> Printf.sprintf "is_minimal(%s)" (emit_expr a)
  | IsDeterministic a -> Printf.sprintf "is_deterministic(%s)" (emit_expr a)
  | Reachable a -> Printf.sprintf "reachable(%s)" (emit_expr a)
  | DeadStates a -> Printf.sprintf "dead_states(%s)" (emit_expr a)
  | AnimateTrace (m, s) -> Printf.sprintf "animate_trace(%s, %s)" (emit_expr m) (emit_expr s)
  (*string operations*)
  | Reverse a -> Printf.sprintf "str_reverse(%s)" (emit_expr a)
  | ConcatStr (a, b) -> Printf.sprintf "str_concat(%s, %s)" (emit_expr a) (emit_expr b)
  | Chars a -> Printf.sprintf "chars(%s)" (emit_expr a)
  | RandomStr (n, a) -> Printf.sprintf "random_str(%s, %s)" (emit_expr n) (emit_expr a)
  | Import (path, _pos) -> Printf.sprintf "import_automaton(%s)" (quoted path)

(* this transition also dict groups all rules by (from_state, symbol), so that non-deterministic transitions like
   q0 a -> q0,   q0 a -> q1 become the single entry: "q0": {"a": ["q0", "q1"]} *)
and emit_automaton_def (body : automaton_body) : string =
  (* build association list: (from_state, symbol_str) -> target list *)
  let rec assoc_add key value = function
    | [] -> [ key, [ value ] ]
    | (k, vs) :: rest when k = key -> (k, vs @ [ value ]) :: rest
    | hd :: rest -> hd :: assoc_add key value rest
  in
  let grouped =
    List.fold_left
      (fun acc (entry : trans_entry) ->
         let sym_str =
           match entry.on_symbol with
           | Sym s -> s      (* real symbol, e.g. "a" *)
           | Eps   -> "eps"  (* epsilon transition     *)
         in
         assoc_add (entry.from_state, sym_str) entry.to_state acc)
      []
      body.transitions  
  in
  let from_states =
    List.sort_uniq compare (List.map (fun ((fs, _), _) -> fs) grouped)
  in
  let emit_state_entry fs =
    let sym_entries =
      List.filter_map
        (fun ((s, sym), tgts) ->
           if s = fs
           then Some (Printf.sprintf "%s: %s" (quoted sym) (py_str_list tgts))
           else None)
        grouped
    in
    Printf.sprintf "%s: {%s}" (quoted fs) (String.concat ", " sym_entries)
  in
  let trans_dict =
    "{" ^ String.concat ", " (List.map emit_state_entry from_states) ^ "}"
  in
  let kind_str =
    match body.kind with
    | NFA -> "\"NFA\""
    | DFA -> "\"DFA\""
  in
  Printf.sprintf
    "Automaton(%s, %s, %s, %s, %s, %s, %s)"
    kind_str
    (quoted body.name)
    (py_str_list body.states)
    (py_str_list body.alphabet)
    (quoted body.start)
    (py_str_list body.final_states)
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
  | VarDecl (name, value_expr, _pos) ->
    Printf.sprintf "%s%s = %s" ind name (emit_expr value_expr)
  | FnDecl (fname, params, body, _pos) ->
    let param_str = String.concat ", " params in
    let header = Printf.sprintf "%sdef %s(%s):" ind fname param_str in
    let body_lines = emit_body body in
    header ^ "\n" ^ String.concat "\n" body_lines
  | AutomatonDecl body ->
    Printf.sprintf "%s%s = %s" ind body.name (emit_automaton_def body)
  (*conditionals*)
  | If (cond, then_body, else_opt, _pos) ->
    let if_line = Printf.sprintf "%sif %s:" ind (emit_expr cond) in
    let then_lines = emit_body then_body in
    let if_block = if_line ^ "\n" ^ String.concat "\n" then_lines in
    (match else_opt with
     | None            -> if_block
     | Some else_body  ->
       let else_line  = Printf.sprintf "%selse:" ind in
       let else_lines = emit_body else_body in
       if_block ^ "\n" ^ else_line ^ "\n" ^ String.concat "\n" else_lines)
  | While (cond, body, _pos) ->
    let while_line = Printf.sprintf "%swhile %s:" ind (emit_expr cond) in
    let body_lines = emit_body body in
    while_line ^ "\n" ^ String.concat "\n" body_lines
  | For (loop_var, iterable, body, _pos) ->
    let for_line = Printf.sprintf "%sfor %s in %s:" ind loop_var (emit_expr iterable) in
    let body_lines = emit_body body in
    for_line ^ "\n" ^ String.concat "\n" body_lines
  | Break _pos -> ind ^ "break"
  | Continue _pos -> ind ^ "continue"
  | Return (None, _pos) -> ind ^ "return"
  | Return (Some e, _pos) -> Printf.sprintf "%sreturn %s" ind (emit_expr e)
  (* I/0 statements*) 
  | Print (e, _pos) -> Printf.sprintf "%sdsl_print(%s)" ind (emit_expr e)
  | Visualize (e, _pos) -> Printf.sprintf "%svisualize(%s)" ind (emit_expr e)
  | Table (e, _pos) -> Printf.sprintf "%stable(%s)" ind (emit_expr e)
  | Stats (e, _pos) -> Printf.sprintf "%sstats(%s)" ind (emit_expr e)
  | Export (e, filepath, _pos) ->
    Printf.sprintf "%sexport(%s, %s)" ind (emit_expr e) (quoted filepath)
  (*append(xs, v)   →  _append(xs, v)
    remove(xs, i)   →  _remove(xs, i)
  used _append / _remove (with underscore) to avoid shadowing python's built-in list methods. *)
  | Append (lst_expr, val_expr, _pos) ->
    Printf.sprintf "%s_append(%s, %s)" ind (emit_expr lst_expr) (emit_expr val_expr)
  | Remove (lst_expr, idx_expr, _pos) ->
    Printf.sprintf "%s_remove(%s, %s)" ind (emit_expr lst_expr) (emit_expr idx_expr)
  (* expression statement *)
  | ExprStmt (Assign (name, value_expr, _pos)) ->
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

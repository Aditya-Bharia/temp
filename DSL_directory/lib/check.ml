open Ast

type error = 

  (* name resolution *)

  | UnknownVariable of string * pos
  | UnknownFunction of string * pos
  | KeywordasVar of string * pos
  | BuiltinRedefinition of string * pos

  (* Duplicate Declarations *)

  | DuplicateVariable of string * pos
  | DuplicateFunction of string * pos
  | DuplicateAutomaton of string * pos
  | DuplicateState of string * pos
  | DuplicateAlphabet of string * pos
  | DuplicateFinalState of string * pos

  (* Automaton Body *)
  
  | StartNotInStates of string * string * pos
  | FinalNotInStates of string * string * pos
  | TransitionSourceNotInStates of string * string * pos
  | TransitionDestNotInStates of string * string * pos
  | TransitionSymbolNotInAlphabet of string * string * pos
  | EpsInDFA of string * pos
  | DFANondeterministic of string * string * pos
  | EmptyStates of string * pos
  | EmptyAlphabet of string * pos

  (* Type Level Errors *)

  | FunctionRequiresDFA of string * pos
  
  (* Control Flow Errors *)

  | BreakOutsideLoop of pos 
  | ContinueOutsideLoop of pos
  | ReturnOutsideFunction of pos
  | ForVarShadowsOuter of string * pos

let error_msg p msg = Printf.sprintf "line %d col %d: %s" p.line p.col msg

let string_of_error = function 

  | UnknownVariable (s,p)      -> error_msg p (Printf.sprintf "Undeclared Variable '%s'" s)
  | UnknownFunction (s,p)      -> error_msg p (Printf.sprintf "Unknown Function '%s'" s)
  | KeywordasVar (s,p)         -> error_msg p (Printf.sprintf "'%s' is reserved keyword, cannot be used as variable name" s)
  | BuiltinRedefinition (s,p)  -> error_msg p (Printf.sprintf "'%s' is a built-in name and cannot be redefined" s)

  | DuplicateVariable (s,p)    -> error_msg p (Printf.sprintf "'%s' is defined as a variable previously" s)
  | DuplicateFunction (s,p)    -> error_msg p (Printf.sprintf "'%s' is defined as a function previously" s)
  | DuplicateAutomaton (s,p)   -> error_msg p (Printf.sprintf "'%s' automaton defined previously" s)
  | DuplicateState (s,p)       -> error_msg p (Printf.sprintf "'%s' is present more than once in states" s)
  | DuplicateAlphabet (s,p)    -> error_msg p (Printf.sprintf "'%s' is present more than once in alphabets" s)
  | DuplicateFinalState (s,p)  -> error_msg p (Printf.sprintf "'%s' is present more than once in final states" s)
  
  | StartNotInStates (s,a,p)               -> error_msg p (Printf.sprintf "'%s' start state is not present in states list of %s" s a)
  | FinalNotInStates (s,a,p)               -> error_msg p (Printf.sprintf "'%s' final state is not present in final states of %s" s a)
  | TransitionSourceNotInStates (s,a,p)    -> error_msg p (Printf.sprintf "'%s' transition source state is not present in states of %s" s a)
  | TransitionDestNotInStates (s,a,p)      -> error_msg p (Printf.sprintf "'%s' transition destination is not present in states of %s" s a)
  | TransitionSymbolNotInAlphabet (s,a,p)  -> error_msg p (Printf.sprintf "'%s' transition symbol is not present in alphabet of %s" s a)
  | EpsInDFA (s,p)                         -> error_msg p (Printf.sprintf "'%s' DFA has Epsilon" s)
  | DFANondeterministic (s,a,p)            -> error_msg p (Printf.sprintf "'%s' duplicate transition in DFA %s" s a)
  | EmptyStates (s,p)                      -> error_msg p (Printf.sprintf "'%s' automaton is declared with no states" s)
  | EmptyAlphabet (s,p)                    -> error_msg p (Printf.sprintf "'%s' automaton is declared with no alphabets" s)

  | FunctionRequiresDFA (s,p)  -> error_msg p (Printf.sprintf "function given '%s' automaton as parameter but requires DFA" s)

  | BreakOutsideLoop p         -> error_msg p (Printf.sprintf "break used outside loop")
  | ContinueOutsideLoop p      -> error_msg p (Printf.sprintf "continue used outside loop")
  | ReturnOutsideFunction p    -> error_msg p (Printf.sprintf "Return used outside function")
  | ForVarShadowsOuter (s,p)   -> error_msg p (Printf.sprintf "%s var used in the outer loop" s)

module SSet = Set.Make(String)
 
let syntax_keywords = SSet.of_list ["var"; "fn"; "if"; "else"; "while"; "for"; "in";"return"; "break"; "continue"; "NFA"; "DFA";"states"; "alphabet"; "start"; "final"; "transition"; "eps";"true"; "false"; "and"; "or"; "not"]
 
let builtin_names = SSet.of_list ["union"; "intersection"; "difference"; "complement"; "concat_lang";"kleene_star"; "kleene_plus"; "reverse_lang";"determinize"; "minimize"; "regex_to_nfa"; "nfa_to_regex"; "dfa_to_regex";"accepts"; "trace"; "equivalent"; "regex_equivalent"; "validate";"subset"; "is_empty"; "is_finite"; "is_minimal"; "is_deterministic";"reachable"; "dead_states";"print"; "visualize"; "table"; "stats"; "export"; "import";"reverse"; "concat"; "chars"; "random_str"; "append"; "remove"]

type name_kind = IsVar | IsFn | IsNFA | IsDFA

type env = {
  names : (string * name_kind) list;
  in_loop : bool;
  in_fn : bool;
}

let empty_env = { names = []; in_loop = false; in_fn = false }
 
let lookup name env = List.assoc_opt name env.names
 
let is_declared name env = lookup name env <> None

let check_new_name name pos env = 
  if SSet.mem name syntax_keywords then 
    [KeywordasVar (name, pos)]
  else if SSet.mem name builtin_names then 
    [BuiltinRedefinition (name, pos)]
  else
    match lookup name env with 
    | Some IsVar -> [DuplicateVariable (name, pos)]
    | Some IsFn  -> [DuplicateFunction (name, pos)]
    | Some IsNFA | Some IsDFA -> [DuplicateAutomaton (name, pos)]
    | None -> []

let collect_decls (prog : program) : env * error list =
  List.fold_left (fun (env, errs) stmt ->
    match stmt with
 
    | VarDecl (name, _, p) ->
        let e  = check_new_name name p env in
        let env' = { env with names = env.names @ [(name, IsVar)] } in
        (env', errs @ e)
 
    | FnDecl (name, _, _, p) ->
        let e  = check_new_name name p env in
        let env' = { env with names = env.names @ [(name, IsFn)] } in
        (env', errs @ e)
 
    | AutomatonDecl body ->
        let kind = if body.kind = NFA then IsNFA else IsDFA in
        let e    = check_new_name body.name body.pos env in
        let env' = { env with names = env.names @ [(body.name, kind)] } in
        (env', errs @ e)
 
    | _ -> (env, errs)
 
  ) (empty_env, []) prog


let check_automaton_body (body: automaton_body) : error list = 
  let m = body.name in 
  let p = body.pos in
  let errs = ref [] in 
  let add e = errs := !errs @ [e] in 

  if body.states = [] then add (EmptyStates (m, p));

  let states_set   = SSet.of_list body.states in
  let alphabet_set = SSet.of_list body.alphabet in
 
  ignore (List.fold_left (fun seen s ->
    if SSet.mem s seen
    then (add (DuplicateState (s, p)); seen)
    else SSet.add s seen
  ) SSet.empty body.states);

  ignore (List.fold_left (fun seen s ->
    if SSet.mem s seen
    then (add (DuplicateAlphabet (s, p)); seen)
    else SSet.add s seen
  ) SSet.empty body.alphabet);
 
  ignore (List.fold_left (fun seen s ->
    if SSet.mem s seen
    then (add (DuplicateFinalState (s, p)); seen)
    else SSet.add s seen
  ) SSet.empty body.final_states);
 
  if not (SSet.mem body.start states_set) then
    add (StartNotInStates (body.start, m, p));
 
  List.iter (fun s ->
    if not (SSet.mem s states_set) then
      add (FinalNotInStates (s, m, p))
  ) body.final_states;

  let dfa_pairs = Hashtbl.create 16 in
  List.iter (fun (te : trans_entry) ->
    let tp = te.pos in
 
    if not (SSet.mem te.from_state states_set) then
      add (TransitionSourceNotInStates (te.from_state, m, tp));
 
    if not (SSet.mem te.to_state states_set) then
      add (TransitionDestNotInStates (te.to_state, m, tp));
 
    (match te.on_symbol with
     | Eps ->
         if body.kind = DFA then add (EpsInDFA (m, tp))
     | Sym s ->
       if body.alphabet <> [] && not (SSet.mem s alphabet_set) then
           add (TransitionSymbolNotInAlphabet (s, m, tp));
         if body.kind = DFA then begin
           let key = te.from_state ^ "\x00" ^ s in
           if Hashtbl.mem dfa_pairs key then
             add (DFANondeterministic (
               Printf.sprintf "state '%s', symbol '%s'" te.from_state s,
               m, tp))
           else
             Hashtbl.add dfa_pairs key ()
         end)
  ) body.transitions;
 
  !errs


let kind_of_arg env expr =
  match expr with
  | Var (name, _) ->
      (match lookup name env with
       | Some IsNFA -> Some NFA
       | Some IsDFA -> Some DFA
       | _          -> None)
  | _ -> None
 
let name_of_arg = function
  | Var (name, _) -> name
  | _             -> "argument"

let require_automaton_ref = function
  | Var _ -> []
  | _ -> [UnknownVariable ("<automaton>", dummy_pos)]


let rec check_expr (env: env) (expr: expr) : error list = 
  match expr with 

  | IntLit _ | StrLit _ | BoolLit _ -> []

  | ListLit elems -> List.concat_map (check_expr env) elems

  | Var (name, p) -> 
      if SSet.mem name builtin_names then []
      else if not (is_declared name env) then [UnknownVariable (name, p)]
      else []

  | Binop (_, l, r) -> check_expr env l @ check_expr env r
  | Unop  (_, e)    -> check_expr env e

  | Assign (name, rhs, p) ->
      let lv = if not (is_declared name env) then [UnknownVariable (name, p)]
               else [] in
      lv @ check_expr env rhs
 
  | Index (e, i) -> check_expr env e @ check_expr env i
 
  | Call (Var (name, p), args) ->
      let fn_errs =
        if SSet.mem name builtin_names then []
        else (match lookup name env with
              | Some IsFn -> []
              | _         -> [UnknownFunction (name, p)])
      in
      fn_errs @ List.concat_map (check_expr env) args
 
  | Call (callee, args) ->
      check_expr env callee @ List.concat_map (check_expr env) args
 
  | Import _ -> []

    | Union (a, b) | Intersection (a, b) | Difference (a, b) | ConcatLang (a, b) ->
      require_automaton_ref a @ require_automaton_ref b

  | Complement (a, p) ->
      let type_err =
        match kind_of_arg env a with
        | Some NFA -> [FunctionRequiresDFA (name_of_arg a, p)]
        | _        -> []
      in
      type_err @ require_automaton_ref a

  | DfaToRegex (a, p) ->
      let type_err =
        match kind_of_arg env a with
        | Some NFA -> [FunctionRequiresDFA (name_of_arg a, p)]
        | _        -> []
      in
      type_err @ check_expr env a

  | IsMinimal (a, p) ->
      let type_err =
        match kind_of_arg env a with
        | Some NFA -> [FunctionRequiresDFA (name_of_arg a, p)]
        | _        -> []
      in
      type_err @ check_expr env a

  | KleeneStar a | KleenePlus a | ReverseLang a -> check_expr env a
 
  | Determinize a | Minimize a | RegexToNfa a | NfaToRegex a -> check_expr env a

      | Accepts (a, b) ->
      require_automaton_ref a @ check_expr env b

      | Trace (a, b) | Equivalent (a, b) | Subset (a, b) ->
        require_automaton_ref a @ require_automaton_ref b

    | RegexEquiv (a, b) ->
      check_expr env a @ check_expr env b

  | Validate a | IsEmpty a | IsFinite a | IsDeterministic a | Reachable a | DeadStates a ->
      check_expr env a
 
  | Reverse a | Chars a -> check_expr env a
  | ConcatStr (a, b) | RandomStr (a, b) -> check_expr env a @ check_expr env b

and check_stmt (env : env) (stmt : stmt) : error list =
  match stmt with
 
  | VarDecl (_, init, _) ->
      check_expr env init
 
  | FnDecl (_, params, body, _) ->
      let inner =
        { names   = env.names @ List.map (fun p -> (p, IsVar)) params;
          in_fn   = true;
          in_loop = false }
      in
      check_stmts inner body
 
  | AutomatonDecl body ->
      check_automaton_body body
 
  | If (cond, then_b, else_b, _) ->
      check_expr env cond
      @ check_stmts env then_b
      @ (match else_b with None -> [] | Some b -> check_stmts env b)
 
  | While (cond, body, _) ->
      check_expr env cond
      @ check_stmts { env with in_loop = true } body
 
  | For (var, iter, body, p) ->
      let shadow = if is_declared var env then [ForVarShadowsOuter (var, p)] else [] in
      let inner  =
        { env with
          names   = env.names @ [(var, IsVar)];
          in_loop = true }
      in
      shadow @ check_expr env iter @ check_stmts inner body
 
  | Return (expr_opt, p) ->
      let scope = if not env.in_fn then [ReturnOutsideFunction p] else [] in
      scope @ (match expr_opt with None -> [] | Some e -> check_expr env e)
 
  | Break p    -> if not env.in_loop then [BreakOutsideLoop p]    else []
  | Continue p -> if not env.in_loop then [ContinueOutsideLoop p] else []
 
  | Print     (e, _)    -> check_expr env e
  | Visualize (e, _)    -> check_expr env e
  | Table     (e, _)    -> check_expr env e
  | Stats     (e, _)    -> check_expr env e
  | Export    (e, _, _) -> check_expr env e
  | Append    (xs, v, _) -> check_expr env xs @ check_expr env v
  | Remove    (xs, i, _) -> check_expr env xs @ check_expr env i
  | ExprStmt  e -> check_expr env e
 
and check_stmts env stmts =
  List.concat_map (check_stmt env) stmts
 

type result =
  | Ok
  | Errors of error list
 
let check (prog : program) : result =

  let (env, decl_errors) = collect_decls prog in
 
  let use_errors = check_stmts env prog in
 
  let all_errors = decl_errors @ use_errors in
 
  let seen = Hashtbl.create 32 in
  let unique = List.filter (fun e ->
    let key = string_of_error e in
    if Hashtbl.mem seen key then false
    else (Hashtbl.add seen key (); true)
  ) all_errors in

  let pos_of = function
    | UnknownVariable (_, p)    | UnknownFunction (_, p)
    | KeywordasVar (_, p)       | BuiltinRedefinition (_, p)
    | DuplicateVariable (_, p)  | DuplicateFunction (_, p)
    | DuplicateAutomaton (_, p) | DuplicateState (_, p)
    | DuplicateAlphabet (_, p)  | DuplicateFinalState (_, p)
    | EpsInDFA (_, p)           | EmptyStates (_, p)
    | EmptyAlphabet (_, p)      | FunctionRequiresDFA (_, p)
    | ForVarShadowsOuter (_, p)
    | BreakOutsideLoop p | ContinueOutsideLoop p | ReturnOutsideFunction p
    | StartNotInStates (_, _, p)          | FinalNotInStates (_, _, p)
    | TransitionSourceNotInStates (_, _, p) | TransitionDestNotInStates (_, _, p)
    | TransitionSymbolNotInAlphabet (_, _, p) | DFANondeterministic (_, _, p) -> p
  in
  let sorted = List.sort (fun a b ->
    let pa = pos_of a and pb = pos_of b in
    let lc = compare pa.line pb.line in
    if lc <> 0 then lc else compare pa.col pb.col
  ) unique in
 
  match sorted with
  | [] -> Ok
  | es -> Errors es

 
let print_result = function
  | Ok ->
      print_endline "Semantic check passed — no errors."
  | Errors errs ->
      Printf.printf "Semantic check failed with %d error(s):\n" (List.length errs);
      List.iteri (fun i e ->
        Printf.printf "  [%d] %s\n" (i + 1) (string_of_error e)
      ) errs

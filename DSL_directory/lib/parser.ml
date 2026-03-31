(* parser.ml — Recursive-descent parser for AutomataGen DSL
   Input  : token list produced by Tokenizer.tokenize
   Output : Ast.program  (= Ast.stmt list)
   Errors : failwith with message "line L, col C: <description>" *)

open Ast

(* Alias so every inline annotation is short *)
type tok = Tokenizer.token
type toks = Tokenizer.token list

(* ══════════════════════════════════════════════════════════════════════════
   Token-list helpers
   ══════════════════════════════════════════════════════════════════════════ *)

let peek (ts : toks) : tok = match ts with
  | t :: _ -> t
  | [] -> failwith "Parser: unexpected end of input"

let advance (ts : toks) : tok * toks = match ts with
  | t :: rest -> (t, rest)
  | [] -> failwith "Parser: unexpected end of input"

let expect (kind : Tokenizer.token_kind) (ts : toks) : tok * toks =
  match ts with
  | (t : tok) :: rest when t.kind = kind -> (t, rest)
  | (t : tok) :: _ ->
      failwith (Printf.sprintf "line %d, col %d: expected %s but got '%s'"
        t.line t.col
        (match kind with
         | LEFT_CURL -> "{" | RIGHT_CURL -> "}" | LEFT_PAR -> "("
         | RIGHT_PAR -> ")" | LEFT_BRACKET -> "[" | RIGHT_BRACKET -> "]"
         | COMMA -> "," | ASSIGN -> "=" | ARROW -> "->" | IDF -> "identifier"
         | STR -> "string" | INT -> "integer" | IN -> "in" | _ -> "token")
        t.text)
  | [] -> failwith "Parser: unexpected end of input in expect"

let pos_of (t : tok) : pos = { line = t.line; col = t.col }

(* ══════════════════════════════════════════════════════════════════════════
   Expression parser  (precedence lowest → highest)
   ══════════════════════════════════════════════════════════════════════════ *)

let rec parse_expr (ts : toks) = parse_assign ts

and parse_assign (ts : toks) =
  match ts with
  | (t1 : tok) :: (t2 : tok) :: rest
    when t1.kind = IDF && t2.kind = ASSIGN ->
      let p = pos_of t1 in
      let (rhs, rest2) = parse_or rest in
      (Assign (t1.text, rhs, p), rest2)
  | _ -> parse_or ts

and parse_or (ts : toks) =
  let (left, rest) = parse_and ts in
  parse_or_rest left rest

and parse_or_rest left (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = OR ->
      let (right, rest2) = parse_and rest in
      parse_or_rest (Binop (Or_placeholder, left, right)) rest2
  | _ -> (left, ts)

and parse_and (ts : toks) =
  let (left, rest) = parse_not ts in
  parse_and_rest left rest

and parse_and_rest left (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = AND ->
      let (right, rest2) = parse_not rest in
      parse_and_rest (Binop (And_placeholder, left, right)) rest2
  | _ -> (left, ts)

and parse_not (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = NOT ->
      let _ = t in
      let (e, rest2) = parse_not rest in
      (Unop (Not, e), rest2)
  | _ -> parse_compare ts

and parse_compare (ts : toks) =
  let (left, rest) = parse_add ts in
  parse_compare_rest left rest

and parse_compare_rest left (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = EQ  -> let (r,t2) = parse_add rest in parse_compare_rest (Binop(Eq,  left, r)) t2
  | (t : tok) :: rest when t.kind = NEQ -> let (r,t2) = parse_add rest in parse_compare_rest (Binop(Neq, left, r)) t2
  | (t : tok) :: rest when t.kind = LESS-> let (r,t2) = parse_add rest in parse_compare_rest (Binop(Lt,  left, r)) t2
  | (t : tok) :: rest when t.kind = LEQ -> let (r,t2) = parse_add rest in parse_compare_rest (Binop(Leq, left, r)) t2
  | (t : tok) :: rest when t.kind = MORE-> let (r,t2) = parse_add rest in parse_compare_rest (Binop(Gt,  left, r)) t2
  | (t : tok) :: rest when t.kind = GEQ -> let (r,t2) = parse_add rest in parse_compare_rest (Binop(Geq, left, r)) t2
  | _ -> (left, ts)

and parse_add (ts : toks) =
  let (left, rest) = parse_mul ts in
  parse_add_rest left rest

and parse_add_rest left (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = PLUS  -> let (r,t2) = parse_mul rest in parse_add_rest (Binop(Add, left, r)) t2
  | (t : tok) :: rest when t.kind = MINUS -> let (r,t2) = parse_mul rest in parse_add_rest (Binop(Sub, left, r)) t2
  | _ -> (left, ts)

and parse_mul (ts : toks) =
  let (left, rest) = parse_unary ts in
  parse_mul_rest left rest

and parse_mul_rest left (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = STAR  -> let (r,t2) = parse_unary rest in parse_mul_rest (Binop(Mul, left, r)) t2
  | (t : tok) :: rest when t.kind = SLASH -> let (r,t2) = parse_unary rest in parse_mul_rest (Binop(Div, left, r)) t2
  | _ -> (left, ts)

and parse_unary (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = MINUS ->
      let _ = t in
      let (e, rest2) = parse_unary rest in
      (Unop (Neg, e), rest2)
  | _ -> parse_postfix ts

and parse_postfix (ts : toks) =
  let (base, rest) = parse_primary ts in
  parse_postfix_rest base rest

and parse_postfix_rest base (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = LEFT_PAR ->
      let _ = t in
      let (args, rest2) = parse_arg_list rest in
      parse_postfix_rest (Call (base, args)) rest2
  | (t : tok) :: rest when t.kind = LEFT_BRACKET ->
      let _ = t in
      let (idx, rest2) = parse_expr rest in
      let (_, rest3) = expect RIGHT_BRACKET rest2 in
      parse_postfix_rest (Index (base, idx)) rest3
  | _ -> (base, ts)

and parse_arg_list (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = RIGHT_PAR -> let _ = t in ([], rest)
  | _ ->
      let (first, rest) = parse_expr ts in
      let rec loop acc (ts : toks) =
        match ts with
        | (t : tok) :: rest when t.kind = COMMA ->
            let _ = t in
            let (e, rest2) = parse_expr rest in
            loop (acc @ [e]) rest2
        | (t : tok) :: rest when t.kind = RIGHT_PAR ->
            let _ = t in (acc, rest)
        | (t : tok) :: _ ->
            failwith (Printf.sprintf "line %d, col %d: expected ',' or ')' in argument list"
              t.line t.col)
        | [] -> failwith "Parser: unterminated argument list"
      in
      loop [first] rest

and parse_primary (ts : toks) =
  let t = peek ts in
  match t.kind with

  | INT ->
      let (t, rest) = advance ts in
      (IntLit (int_of_string t.lit_val), rest)

  | STR ->
      let (t, rest) = advance ts in
      (StrLit t.lit_val, rest)

  | TRUE  -> let (_, rest) = advance ts in (BoolLit true,  rest)
  | FALSE -> let (_, rest) = advance ts in (BoolLit false, rest)

  | LEFT_BRACKET ->
      let (_, rest) = advance ts in
      parse_list_literal rest

  | LEFT_PAR ->
      let (_, rest) = advance ts in
      let (e, rest2) = parse_expr rest in
      let (_, rest3) = expect RIGHT_PAR rest2 in
      (e, rest3)

  | IMPORT ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (path_tok, rest3) = expect STR rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Import (path_tok.lit_val, p), rest4)

  | UNION ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (b, rest5) =
      match rest3 with
      | (t : tok) :: rest4 when t.kind = COMMA ->
        let (b2, rest6) = parse_expr rest4 in
        (b2, rest6)
      | _ ->
        (IntLit 0, rest3)
      in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Union (a, b), rest6)

  | INTERSECTION ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Intersection (a, b), rest6)

  | DIFFERENCE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Difference (a, b), rest6)

  | COMPLEMENT ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Complement (a, p), rest4)

  | CONCAT_LANG ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (ConcatLang (a, b), rest6)

  | KLEENE_STAR ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (KleeneStar a, rest4)

  | KLEENE_PLUS ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (KleenePlus a, rest4)

  | REVERSE_LANG ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (ReverseLang a, rest4)

  | DETERMINIZE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Determinize a, rest4)

  | MINIMIZE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Minimize a, rest4)

  | REGEX_TO_NFA ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (RegexToNfa a, rest4)

  | NFA_TO_REGEX ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (NfaToRegex a, rest4)

  | DFA_TO_REGEX ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (DfaToRegex (a, p), rest4)

  | ACCEPTS ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Accepts (a, b), rest6)

  | TRACE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Trace (a, b), rest6)

  | EQUIVALENT ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Equivalent (a, b), rest6)

  | REGEX_EQUIVALENT ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (RegexEquiv (a, b), rest6)

  | VALIDATE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Validate a, rest4)

  | SUBSET ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Subset (a, b), rest6)

  | IS_EMPTY ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (IsEmpty a, rest4)

  | IS_FINITE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (IsFinite a, rest4)

  | IS_MINIMAL ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (IsMinimal (a, p), rest4)

  | IS_DETERMINISTIC ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (IsDeterministic a, rest4)

  | REACHABLE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Reachable a, rest4)

  | DEAD_STATES ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (DeadStates a, rest4)

  | REVERSE ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Reverse a, rest4)

  | CONCAT ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (ConcatStr (a, b), rest6)

  | CHARS ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Chars a, rest4)

  | RANDOM_STR ->
      let (_, rest) = advance ts in
      let (_, rest2) = expect LEFT_PAR rest in
      let (a, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (b, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (RandomStr (a, b), rest6)

  | IDF ->
      let (t, rest) = advance ts in
      (Var (t.text, pos_of t), rest)

  | _ ->
      failwith (Printf.sprintf "line %d, col %d: unexpected token '%s' in expression"
        t.line t.col t.text)

and parse_list_literal (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = RIGHT_BRACKET -> let _ = t in (ListLit [], rest)
  | _ ->
      let (first, rest) = parse_expr ts in
      let rec loop acc (ts : toks) =
        match ts with
        | (t : tok) :: rest when t.kind = COMMA ->
            let _ = t in
            let (e, rest2) = parse_expr rest in
            loop (acc @ [e]) rest2
        | (t : tok) :: rest when t.kind = RIGHT_BRACKET ->
            let _ = t in (ListLit acc, rest)
        | (t : tok) :: _ ->
            failwith (Printf.sprintf "line %d, col %d: expected ',' or ']' in list literal"
              t.line t.col)
        | [] -> failwith "Parser: unterminated list literal"
      in
      loop [first] rest

(* ══════════════════════════════════════════════════════════════════════════
   Statement parser
   ══════════════════════════════════════════════════════════════════════════ *)

and parse_block (ts : toks) =
  let (_, rest) = expect LEFT_CURL ts in
  let rec loop acc (ts : toks) =
    match ts with
    | (t : tok) :: rest when t.kind = RIGHT_CURL -> let _ = t in (List.rev acc, rest)
    | (t : tok) :: _ when t.kind = END -> failwith "Parser: unterminated block"
    | _ ->
        let (s, rest2) = parse_stmt ts in
        loop (s :: acc) rest2
  in
  loop [] rest

and parse_stmt (ts : toks) =
  let t = peek ts in
  match t.kind with

  | VAR ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (name_tok, rest2) = expect IDF rest in
      let (_, rest3) = expect ASSIGN rest2 in
      let (e, rest4) = parse_expr rest3 in
      (VarDecl (name_tok.text, e, p), rest4)

  | FN ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (name_tok, rest2) = expect IDF rest in
      let (_, rest3) = expect LEFT_PAR rest2 in
      let (params, rest4) = parse_param_list rest3 in
      let (body, rest5) = parse_block rest4 in
      (FnDecl (name_tok.text, params, body, p), rest5)

  | NFA | DFA ->
      let (t, rest) = advance ts in
      let kind = if t.kind = NFA then Ast.NFA else Ast.DFA in
      let p = pos_of t in
      let (name_tok, rest2) = expect IDF rest in
      let (body, rest3) = parse_automaton_body kind name_tok.text p rest2 in
      (AutomatonDecl body, rest3)

  | IF ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (cond, rest2) = parse_or rest in
      let (then_body, rest3) = parse_block rest2 in
      (match rest3 with
       | (t2 : tok) :: rest4 when t2.kind = ELSE ->
           let (else_body, rest5) = parse_block rest4 in
           (If (cond, then_body, Some else_body, p), rest5)
       | _ ->
           (If (cond, then_body, None, p), rest3))

  | WHILE ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (cond, rest2) = parse_or rest in
      let (body, rest3) = parse_block rest2 in
      (While (cond, body, p), rest3)

  | FOR ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (var_tok, rest2) = expect IDF rest in
      let (_, rest3) = expect IN rest2 in
      let (iter, rest4) = parse_or rest3 in
      let (body, rest5) = parse_block rest4 in
      (For (var_tok.text, iter, body, p), rest5)

  | RETURN ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      (match rest with
       | (t2 : tok) :: _ when t2.kind = RIGHT_CURL || t2.kind = END ->
           (Return (None, p), rest)
       | _ ->
           let (e, rest2) = parse_expr rest in
           (Return (Some e, p), rest2))

  | BREAK ->
      let (t, rest) = advance ts in
      (Break (pos_of t), rest)

  | CONTINUE ->
      let (t, rest) = advance ts in
      (Continue (pos_of t), rest)

  | PRINT ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (e, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Print (e, p), rest4)

  | VISUALIZE ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (e, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Visualize (e, p), rest4)

  | TABLE ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (e, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Table (e, p), rest4)

  | STATS ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (e, rest3) = parse_expr rest2 in
      let (_, rest4) = expect RIGHT_PAR rest3 in
      (Stats (e, p), rest4)

  | EXPORT ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (e, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (path_tok, rest5) = expect STR rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Export (e, path_tok.lit_val, p), rest6)

  | APPEND ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (xs, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (v, rest5) = parse_expr rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Append (xs, v, p), rest6)

  | REMOVE ->
      let (t, rest) = advance ts in
      let p = pos_of t in
      let (_, rest2) = expect LEFT_PAR rest in
      let (xs, rest3) = parse_expr rest2 in
      let (_, rest4) = expect COMMA rest3 in
      let (idx_tok, rest5) = expect INT rest4 in
      let (_, rest6) = expect RIGHT_PAR rest5 in
      (Remove (xs, IntLit (int_of_string idx_tok.lit_val), p), rest6)

  | _ ->
      let (e, rest) = parse_expr ts in
      (ExprStmt e, rest)

and parse_param_list (ts : toks) =
  match ts with
  | (t : tok) :: rest when t.kind = RIGHT_PAR -> let _ = t in ([], rest)
  | _ ->
      let (first, rest) = expect IDF ts in
      let rec loop acc (ts : toks) =
        match ts with
        | (t : tok) :: rest when t.kind = COMMA ->
            let _ = t in
            let (p, rest2) = expect IDF rest in
            loop (acc @ [p.text]) rest2
        | (t : tok) :: rest when t.kind = RIGHT_PAR ->
            let _ = t in (acc, rest)
        | (t : tok) :: _ ->
            failwith (Printf.sprintf "line %d, col %d: expected ',' or ')' in parameter list"
              t.line t.col)
        | [] -> failwith "Parser: unterminated parameter list"
      in
      loop [first.text] rest

(* ══════════════════════════════════════════════════════════════════════════
   Automaton body parser
   Order enforced: states → alphabet → start → final → transition
   ══════════════════════════════════════════════════════════════════════════ *)

and parse_automaton_body kind name p (ts : toks) =
  let (_, rest0) = expect LEFT_CURL ts in

  let rec loop states alphabet start_opt final_states transitions (ts : toks) =
    match ts with
    | (t : tok) :: rest when t.kind = RIGHT_CURL ->
        ({ kind; name; states; alphabet;
           start = (match start_opt with Some s -> s | None -> "");
           final_states; transitions; pos = p },
         rest)

    | (t : tok) :: rest when t.kind = STATES ->
        let (_, rest2) = expect LEFT_CURL rest in
        let (states2, rest3) = parse_id_list rest2 in
        let (_, rest4) = expect RIGHT_CURL rest3 in
        loop states2 alphabet start_opt final_states transitions rest4

    | (t : tok) :: rest when t.kind = ALPHABET ->
        let (_, rest2) = expect LEFT_CURL rest in
        let (alphabet2, rest3) = parse_id_list rest2 in
        let (_, rest4) = expect RIGHT_CURL rest3 in
        loop states alphabet2 start_opt final_states transitions rest4

    | (t : tok) :: rest when t.kind = START ->
        let (start_tok, rest2) = expect IDF rest in
        loop states alphabet (Some start_tok.text) final_states transitions rest2

    | (t : tok) :: rest when t.kind = FINAL ->
        let (_, rest2) = expect LEFT_CURL rest in
        let (final_states2, rest3) = parse_id_list rest2 in
        let (_, rest4) = expect RIGHT_CURL rest3 in
        loop states alphabet start_opt final_states2 transitions rest4

    | (t : tok) :: rest when t.kind = TRANSITION ->
        (match rest with
         | (t2 : tok) :: rest2 when t2.kind = LEFT_CURL ->
             let (entries, rest3) = parse_transitions rest2 in
             let (_, rest4) = expect RIGHT_CURL rest3 in
             loop states alphabet start_opt final_states (transitions @ entries) rest4
         | _ ->
             let (entry, rest2) = parse_trans_entry rest in
             loop states alphabet start_opt final_states (transitions @ [entry]) rest2)

    | (t : tok) :: _ ->
        failwith (Printf.sprintf "line %d, col %d: unexpected token '%s' in automaton body"
          t.line t.col t.text)
    | [] -> failwith "Parser: unexpected end in automaton body"
  in
  loop [] [] None [] [] rest0

and parse_id_list (ts : toks) =
  match ts with
  | (t : tok) :: _ when t.kind = RIGHT_CURL -> ([], ts)
  | (t : tok) :: rest when t.kind = IDF ->
      let text = t.text in
      let rec loop acc (ts : toks) =
        match ts with
        | (tc : tok) :: (ti : tok) :: rest2
          when tc.kind = COMMA && ti.kind = IDF ->
            loop (acc @ [ti.text]) rest2
        | _ -> (acc, ts)
      in
      loop [text] rest
  | _ -> ([], ts)

and parse_transitions (ts : toks) =
  match ts with
  | (t : tok) :: _ when t.kind = RIGHT_CURL -> let _ = t in ([], ts)
  | _ ->
      let (entry, rest) = parse_trans_entry ts in
      let rec loop acc (ts : toks) =
        match ts with
        | (tc : tok) :: (tr : tok) :: _
          when tc.kind = COMMA && tr.kind = RIGHT_CURL ->
            let _ = tc in let _ = tr in
            (acc, List.tl ts)
        | (t : tok) :: rest2 when t.kind = COMMA ->
            let _ = t in
            (match rest2 with
             | (t2 : tok) :: _ when t2.kind = RIGHT_CURL ->
                 let _ = t2 in (acc, rest2)
             | _ ->
                 let (e, rest3) = parse_trans_entry rest2 in
                 loop (acc @ [e]) rest3)
        | _ -> (acc, ts)
      in
      loop [entry] rest

and parse_trans_entry (ts : toks) =
  let (from_tok, rest1) = expect IDF ts in
  let p = pos_of from_tok in
  let (sym, rest2) =
    match rest1 with
    | (t : tok) :: r when t.kind = EPS -> (Eps, r)
    | (t : tok) :: r when t.kind = IDF -> (Sym t.text, r)
    | (t : tok) :: _ ->
        failwith (Printf.sprintf "line %d, col %d: expected transition symbol or 'eps', got '%s'"
          t.line t.col t.text)
    | [] -> failwith "Parser: unexpected end in transition entry"
  in
  let rest3 =
    match rest2 with
    | (t : tok) :: r when t.kind = ARROW -> r
    | _ -> rest2
  in
  let (to_tok, rest4) = expect IDF rest3 in
  ({ from_state = from_tok.text; on_symbol = sym;
     to_state = to_tok.text; pos = p },
   rest4)

(* ══════════════════════════════════════════════════════════════════════════
   Top-level entry point
   ══════════════════════════════════════════════════════════════════════════ *)

let parse (ts : toks) : program =
  let rec loop acc (ts : toks) =
    match ts with
    | (t : tok) :: _ when t.kind = END -> List.rev acc
    | _ ->
        let (s, rest) = parse_stmt ts in
        loop (s :: acc) rest
  in
  loop [] ts
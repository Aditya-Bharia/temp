type token_kind =
  (* ── Control keywords ── *)
  | VAR | FN | RETURN | IF | ELSE | WHILE | FOR | IN | BREAK | CONTINUE
  (* ── Automaton construction ── *)
  | NFA | DFA | STATES | ALPHABET | START | FINAL | TRANSITION | EPS
  (* ── Language operations ── *)
  | UNION | INTERSECTION | DIFFERENCE | COMPLEMENT | CONCAT_LANG
  | KLEENE_STAR | KLEENE_PLUS | REVERSE_LANG
  (* ── Transformations ── *)
  | DETERMINIZE | MINIMIZE | REGEX_TO_NFA | NFA_TO_REGEX | DFA_TO_REGEX
  (* ── Analysis functions ── *)
  | ACCEPTS | TRACE | EQUIVALENT | REGEX_EQUIVALENT | VALIDATE
  | SUBSET | IS_EMPTY | IS_FINITE | IS_MINIMAL | IS_DETERMINISTIC
  | REACHABLE | DEAD_STATES
  (* ── I/O and export/ import ── *)
  | PRINT | VISUALIZE | TABLE | STATS | EXPORT | IMPORT
  (* ── String operations ── *)
  | REVERSE | CONCAT | CHARS | RANDOM_STR
  (* ── List operations ── *)
  | APPEND | REMOVE
  (* ── Boolean literals and operators ── *)
  | TRUE | FALSE | AND | OR | NOT
  (* ── Delimiters ── *)
  | LEFT_CURL | RIGHT_CURL
  | LEFT_PAR  | RIGHT_PAR
  | LEFT_BRACKET | RIGHT_BRACKET
  | COMMA | DOT
  (* ── Arithmetic operators ── *)
  | PLUS | MINUS | STAR | SLASH
  (* ── Comparison and assignment operators ── *)
  | ASSIGN
  | EQ | NEQ
  | LESS | MORE
  | LEQ  | GEQ
  (* ── Automaton transition arrow ── *)
  | ARROW
  (* ── Value-carrying token kinds ── *)
  | IDF
  | STR
  | INT
  (* ──THIS IS THE END ── *)
  | END

type token = { kind : token_kind; text : string; lit_val : string; line : int; col : int;}

(* ── Keyword hash table ── *)
let keyword_table : (string, token_kind) Hashtbl.t = Hashtbl.create 64

let () =
  List.iter (fun (str, keyword) -> Hashtbl.add keyword_table str keyword)
  [
    (* ── Control keywords ── *)
    "var", VAR; "fn", FN; "return", RETURN; "if", IF; "else", ELSE;"while", WHILE; "for", FOR; "in", IN; "break", BREAK; "continue", CONTINUE;
    (* ── Automaton construction ── *)
    "NFA", NFA; "DFA", DFA;"states", STATES; "alphabet", ALPHABET; "start", START; "final", FINAL;"transition", TRANSITION; "eps", EPS;
    (* ── Language operations ── *)
    "union", UNION; "intersection", INTERSECTION; "difference", DIFFERENCE;"complement", COMPLEMENT; "concat_lang", CONCAT_LANG;"kleene_star", KLEENE_STAR; "kleene_plus", KLEENE_PLUS; "reverse_lang", REVERSE_LANG;
    (* ── Transformations ── *)
    "determinize", DETERMINIZE; "minimize", MINIMIZE;"regex_to_nfa", REGEX_TO_NFA; "nfa_to_regex", NFA_TO_REGEX; "dfa_to_regex", DFA_TO_REGEX;
    (* ── Analysis functions ── *)
    "accepts", ACCEPTS; "trace", TRACE; "equivalent", EQUIVALENT;"regex_equivalent", REGEX_EQUIVALENT; "validate", VALIDATE;"subset", SUBSET; "is_empty", IS_EMPTY; "is_finite", IS_FINITE;"is_minimal", IS_MINIMAL; "is_deterministic", IS_DETERMINISTIC;"reachable", REACHABLE; "dead_states", DEAD_STATES;
    (* ── I/O and export/ import ── *)
    "print", PRINT; "visualize", VISUALIZE; "table", TABLE;"stats", STATS; "export", EXPORT; "import", IMPORT;
    (* ── String operations ── *)
    "reverse", REVERSE; "concat", CONCAT; "chars", CHARS; "random_str", RANDOM_STR;
    (* ── List operations ── *)
    "append", APPEND; "remove", REMOVE;
    (* ── Boolean literals and operators ── *)
    "true", TRUE; "false", FALSE; "and", AND; "or", OR; "not", NOT;
  ]

let str_to_kind str =
  match Hashtbl.find_opt keyword_table str with
  | Some k -> k
  | None -> IDF

(* ── Character level helpers ── *)
let rec read_string str chars line col =
  match chars with
  | [] -> failwith (Printf.sprintf "Lexer error at line %d, col %d: String not closed" line col)
  | '"'  :: tail -> (str, tail,line,col+1)
  | '\\' :: '"' :: tail -> read_string (str ^ "\"") tail line (col + 2) (* escape sequence  "say \"hello\"" as say hello and not say \*)
  | '\n' :: tail -> read_string (str ^ "\n") tail (line + 1) 1 (* a new line will reset the column count*)
  | c :: tail -> read_string (str ^ String.make 1 c) tail line (col + 1)

let rec read_number num chars line col =
  match chars with
  | ('0'..'9') as d :: tail -> read_number (num ^ String.make 1 d) tail line (col + 1)
  | _ -> (num, chars, line, col)

let rec read_identifier_or_keyword acc chars line col =
  match chars with
  | ('a'..'z' | 'A'..'Z' | '0'..'9' | '_') as c :: tail -> read_identifier_or_keyword (acc ^ String.make 1 c) tail line (col + 1)
  | _ -> (acc, chars, line, col)

let rec skip_line_comment chars line col =
  match chars with
  | [] -> ([], line, col)
  | '\n' :: tail -> (tail , line+1, 1)
  | _ :: tail -> skip_line_comment tail line (col + 1)

let rec skip_block_comment chars line  col =
  match chars with
  | [] -> failwith (Printf.sprintf "Lexer error at line %d, col %d :Block comment not closed" line col)
  | '*' :: '/' :: tail -> (tail, line, col + 2)
  | '\n' :: tail -> skip_block_comment tail (line + 1) 1
  | _   :: tail -> skip_block_comment tail line(col + 1)

(* ── Main tokenizer ── *)
let rec tokenize chars line col =
  match chars with
  | [] -> [ { kind = END; text = ""; lit_val = "null"; line; col } ]
  | '\n' :: tail -> tokenize tail (line + 1) 1
  (* ── skips any whitespace ── *)
  | (' ' | '\t' | '\r') :: tail -> tokenize tail line (col + 1)
  (* ── comments ── *)
  | '#' :: tail1 ->
      let (tail2, new_line, new_col) = skip_line_comment tail1 line (col + 1) in
      tokenize tail2 new_line new_col
  | '/' :: '*' :: tail1 ->
      let (tail2, new_line, new_col) = skip_block_comment tail1 line (col + 2) in
      tokenize tail2 new_line new_col
  (* ── delimiters ── *)
  | '{' :: tail -> { kind = LEFT_CURL;     text = "{old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '}' :: tail -> { kind = RIGHT_CURL;    text = "}old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '(' :: tail -> { kind = LEFT_PAR;      text = "(old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | ')' :: tail -> { kind = RIGHT_PAR;     text = ")old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '[' :: tail -> { kind = LEFT_BRACKET;  text = "[old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | ']' :: tail -> { kind = RIGHT_BRACKET; text = "]old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | ',' :: tail -> { kind = COMMA;         text = ",old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '.' :: tail -> { kind = DOT;           text = ".old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  (* ── arithmetic operators ── *)
  | '+' :: tail -> { kind = PLUS;  text = "+old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '*' :: tail -> { kind = STAR;  text = "*old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '/' :: tail -> { kind = SLASH; text = "/old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+1)
  (* ── multi-char operators ── *)
  | '-' :: '>' :: tail -> { kind = ARROW;  text = "->old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+2)
  | '-' :: tail -> { kind = MINUS;  text = "-";  lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '=' :: '=' :: tail -> { kind = EQ;     text = "==old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+2)
  | '=' :: tail -> { kind = ASSIGN; text = "=";  lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '!' :: '=' :: tail -> { kind = NEQ;    text = "!=old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+2)
  | '<' :: '=' :: tail -> { kind = LEQ;    text = "<=old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+2)
  | '<' :: tail -> { kind = LESS;   text = "<";  lit_val = "null"; line; col } :: tokenize tail line (col+1)
  | '>' :: '=' :: tail -> { kind = GEQ;    text = ">=old_line"; lit_val = "null"; line; col } :: tokenize tail line (col+2)
  | '>' :: tail -> { kind = MORE;   text = ">";  lit_val = "null"; line; col } :: tokenize tail line (col+1)
  (* ── string literal ── *)
  | '"' :: tail -> let old_line = line and old_col = col in
      let (str, tail2, new_line, new_col) = read_string "" tail line (col + 1) in
      { kind = STR; text = "\"" ^ str ^ "\""; lit_val = str; line = old_line; col = old_col } :: tokenize tail2 new_line new_col
  (* ── integer literal ── *)
  | ('0'..'9') as d :: tail1 ->
      let old_line = line and old_col = col in
      let (num, tail2, new_line, new_col) = read_number (String.make 1 d) tail1 line (col + 1) in
      { kind = INT; text = num; lit_val = num; line = old_line; col = old_col }
      :: tokenize tail2 new_line new_col

  | ('a'..'z' | 'A'..'Z' | '_') as ch :: tail1 ->
      let old_line = line and old_col = col in
      let (word, tail2, new_line, new_col) = read_identifier_or_keyword (String.make 1 ch) tail1 line (col + 1) in
      let k = str_to_kind word in
      { kind = k; text = word; lit_val = "null"; line = old_line; col = old_col }
      :: tokenize tail2 new_line new_col

  | c :: _ ->
      failwith (Printf.sprintf "Lexer error at line %d, col %d: unexpected character '%c'" line col c)

let tokenize chars = tokenize chars 1 1
(* ── Print tokens as string (called from main.ml) ── *)
let rec print_tokens tok_list =
  match tok_list with
  | [] -> ""
  | { kind; text; lit_val; line;col } :: tail -> let kind_to_str = match kind with
      (* ── Control keywords ── *)  
      | VAR -> "VAR" | FN -> "FN" | RETURN -> "RETURN" | IF -> "IF" | ELSE -> "ELSE"| WHILE -> "WHILE" | FOR -> "FOR" | IN -> "IN" | BREAK -> "BREAK" | CONTINUE -> "CONTINUE"
      (* ── Automaton construction ── *)
      | NFA -> "NFA" | DFA -> "DFA" | STATES -> "STATES" | ALPHABET -> "ALPHABET"| START -> "START" | FINAL -> "FINAL" | TRANSITION -> "TRANSITION" | EPS -> "EPS"
      (* ── Language operations ── *)
      | UNION -> "UNION" | INTERSECTION -> "INTERSECTION" | DIFFERENCE -> "DIFFERENCE"| COMPLEMENT -> "COMPLEMENT" | CONCAT_LANG -> "CONCAT_LANG"| KLEENE_STAR -> "KLEENE_STAR" | KLEENE_PLUS -> "KLEENE_PLUS" | REVERSE_LANG -> "REVERSE_LANG"
      (* ── Transformations ── *)
      | DETERMINIZE -> "DETERMINIZE" | MINIMIZE -> "MINIMIZE"| REGEX_TO_NFA -> "REGEX_TO_NFA" | NFA_TO_REGEX -> "NFA_TO_REGEX" | DFA_TO_REGEX -> "DFA_TO_REGEX"
      (* ── Analysis functions ── *)
      | ACCEPTS -> "ACCEPTS" | TRACE -> "TRACE" | EQUIVALENT -> "EQUIVALENT"| REGEX_EQUIVALENT -> "REGEX_EQUIVALENT" | VALIDATE -> "VALIDATE"| SUBSET -> "SUBSET" | IS_EMPTY -> "IS_EMPTY" | IS_FINITE -> "IS_FINITE"| IS_MINIMAL -> "IS_MINIMAL" | IS_DETERMINISTIC -> "IS_DETERMINISTIC"| REACHABLE -> "REACHABLE" | DEAD_STATES -> "DEAD_STATES"
      (* ── I/O and export/ import ── *)
      | PRINT -> "PRINT" | VISUALIZE -> "VISUALIZE" | TABLE -> "TABLE"| STATS -> "STATS" | EXPORT -> "EXPORT" | IMPORT -> "IMPORT"
      (* ── String operations ── *)
      | REVERSE -> "REVERSE" | CONCAT -> "CONCAT" | CHARS -> "CHARS" | RANDOM_STR -> "RANDOM_STR"
      (* ── List operations ── *)
      | APPEND -> "APPEND" | REMOVE -> "REMOVE"
      (* ── Boolean literals and operators ── *)
      | TRUE -> "TRUE" | FALSE -> "FALSE" | AND -> "AND" | OR -> "OR" | NOT -> "NOT"
      (* ── Delimiters ── *)
      | LEFT_CURL -> "LEFT_CURL" | RIGHT_CURL -> "RIGHT_CURL"| LEFT_PAR -> "LEFT_PAR" | RIGHT_PAR -> "RIGHT_PAR"| LEFT_BRACKET -> "LEFT_BRACKET" | RIGHT_BRACKET -> "RIGHT_BRACKET"| COMMA -> "COMMA" | DOT -> "DOT"
      (* ── Arithmetic operators ── *)
      | PLUS -> "PLUS" | MINUS -> "MINUS" | STAR -> "STAR" | SLASH -> "SLASH"
      (* ── Comparison and assignment operators ── *)
      | ASSIGN -> "ASSIGN" | EQ -> "EQ" | NEQ -> "NEQ"| LESS -> "LESS" | MORE -> "MORE" | LEQ -> "LEQ" | GEQ -> "GEQ"
      (* ── Automaton transition arrow ── *)  
      | ARROW -> "ARROW"
      (* ── Value-carrying token kinds ── *) 
      | IDF -> "IDF" | STR -> "STR" | INT -> "INT"
      (* ── THIS IS THE END ── *)
      | END -> "END"
      in
      kind_to_str ^ " " ^ text ^ " " ^ lit_val^ " (line " ^ string_of_int line ^ ", col " ^ string_of_int col ^ ")"^ "\n" ^ print_tokens tail
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

type token = { kind : token_kind; text : string; lit_val : string }

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
  | None   -> IDF

(* ── Character level helpers ── *)
let rec read_string str chars =
  match chars with
  | []                -> failwith "Lexer error: String not closed"
  | '"'  :: tail      -> (str, tail)
  | '\\' :: '"' :: tail -> read_string (str ^ "\"") tail  (* escape sequence  "say \"hello\"" as say hello and not say \*)
  | c    :: tail      -> read_string (str ^ String.make 1 c) tail

let rec read_number num chars =
  match chars with
  | ('0'..'9') as d :: tail -> read_number (num ^ String.make 1 d) tail
  | _                       -> (num, chars)

let rec read_identifier_or_keyword acc chars =
  match chars with
  | ('a'..'z' | 'A'..'Z' | '0'..'9' | '_') as c :: tail -> read_identifier_or_keyword (acc ^ String.make 1 c) tail
  | _ -> (acc, chars)

let rec skip_line_comment chars =
  match chars with
  | []           -> []
  | '\n' :: tail -> tail
  | _    :: tail -> skip_line_comment tail

let rec skip_block_comment chars =
  match chars with
  | []                 -> failwith "Lexer error:Block comment not closed"
  | '*' :: '/' :: tail -> tail
  | _   :: tail        -> skip_block_comment tail

(* ── Main tokenizer ── *)
let rec tokenize chars =
  match chars with
  | [] -> [ { kind = END; text = ""; lit_val = "null" } ]
  (* ── skips any whitespace ── *)
  | (' ' | '\t' | '\n' | '\r') :: tail -> tokenize tail
  (* ── comments ── *)
  | '#' :: tail        -> tokenize (skip_line_comment tail)
  | '/' :: '*' :: tail -> tokenize (skip_block_comment tail)
  (* ── delimiters ── *)
  | '{' :: tail -> { kind = LEFT_CURL;     text = "{"; lit_val = "null" } :: tokenize tail
  | '}' :: tail -> { kind = RIGHT_CURL;    text = "}"; lit_val = "null" } :: tokenize tail
  | '(' :: tail -> { kind = LEFT_PAR;      text = "("; lit_val = "null" } :: tokenize tail
  | ')' :: tail -> { kind = RIGHT_PAR;     text = ")"; lit_val = "null" } :: tokenize tail
  | '[' :: tail -> { kind = LEFT_BRACKET;  text = "["; lit_val = "null" } :: tokenize tail
  | ']' :: tail -> { kind = RIGHT_BRACKET; text = "]"; lit_val = "null" } :: tokenize tail
  | ',' :: tail -> { kind = COMMA;         text = ","; lit_val = "null" } :: tokenize tail
  | '.' :: tail -> { kind = DOT;           text = "."; lit_val = "null" } :: tokenize tail
  (* ── arithmetic operators ── *)
  | '+' :: tail -> { kind = PLUS;  text = "+"; lit_val = "null" } :: tokenize tail
  | '*' :: tail -> { kind = STAR;  text = "*"; lit_val = "null" } :: tokenize tail
  | '/' :: tail -> { kind = SLASH; text = "/"; lit_val = "null" } :: tokenize tail
  (* ── multi-char operators ── *)
  | '-' :: '>' :: tail -> { kind = ARROW;  text = "->"; lit_val = "null" } :: tokenize tail
  | '-' :: tail        -> { kind = MINUS;  text = "-";  lit_val = "null" } :: tokenize tail
  | '=' :: '=' :: tail -> { kind = EQ;     text = "=="; lit_val = "null" } :: tokenize tail
  | '=' :: tail        -> { kind = ASSIGN; text = "=";  lit_val = "null" } :: tokenize tail
  | '!' :: '=' :: tail -> { kind = NEQ;    text = "!="; lit_val = "null" } :: tokenize tail
  | '<' :: '=' :: tail -> { kind = LEQ;    text = "<="; lit_val = "null" } :: tokenize tail
  | '<' :: tail        -> { kind = LESS;   text = "<";  lit_val = "null" } :: tokenize tail
  | '>' :: '=' :: tail -> { kind = GEQ;    text = ">="; lit_val = "null" } :: tokenize tail
  | '>' :: tail        -> { kind = MORE;   text = ">";  lit_val = "null" } :: tokenize tail
  (* ── string literal ── *)
  | '"' :: tail ->
      let (str, tail2) = read_string "" tail in
      { kind = STR; text = "\"" ^ str ^ "\""; lit_val = str } :: tokenize tail2
  (* ── integer literal ── *)
  | ('0'..'9') as d :: tail ->
      let (num, tail2) = read_number (String.make 1 d) tail in
      { kind = INT; text = num; lit_val = num } :: tokenize tail2
  (* ── identifier or keyword ── *)
  | ('a'..'z' | 'A'..'Z' | '_') as c :: tail ->
      let (str, tail2) = read_identifier_or_keyword (String.make 1 c) tail in
      let keyword = str_to_kind str in
      { kind = keyword; text = str; lit_val = "null" } :: tokenize tail2
  (* ── anything else is a lexer error ── *)
  | c :: _ ->
      failwith (Printf.sprintf "Lexer error: unexpected character '%c'" c)

(* ── Print tokens as string (called from main.ml) ── *)
let rec print_tokens tok_list =
  match tok_list with
  | [] -> ""
  | { kind; text; lit_val } :: tail ->
      let kind_to_str = match kind with
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
      kind_to_str ^ " " ^ text ^ " " ^ lit_val ^ "\n" ^ print_tokens tail
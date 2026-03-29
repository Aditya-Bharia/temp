open OUnit2
open Tokenizer

let to_chars s = List.init (String.length s) (String.get s)

let tok s =
  s |> to_chars |> tokenize |> print_tokens

let printer x = x

(* -------- TESTS -------- *)

let test_basic _ =
  let expected =
"VAR var null (line 1, col 1)
IDF x null (line 1, col 5)
ASSIGN = null (line 1, col 7)
INT 10 10 (line 1, col 9)
END  null (line 1, col 11)
"
  in
  assert_equal ~printer expected (tok "var x = 10")

let test_if _ =
  let expected =
"IF if null (line 1, col 1)
TRUE true null (line 1, col 4)
LEFT_CURL { null (line 1, col 9)
RETURN return null (line 1, col 11)
INT 1 1 (line 1, col 18)
RIGHT_CURL } null (line 1, col 20)
END  null (line 1, col 21)
"
  in
  assert_equal ~printer expected (tok "if true { return 1 }")

let test_arrow _ =
  let expected =
"IDF q0 null (line 1, col 1)
ARROW -> null (line 1, col 4)
IDF q1 null (line 1, col 7)
END  null (line 1, col 9)
"
  in
  assert_equal ~printer expected (tok "q0 -> q1")

let test_string _ =
  let expected =
"STR \"hello\" hello (line 1, col 1)
END  null (line 1, col 8)
"
  in
  assert_equal ~printer expected (tok "\"hello\"")

let test_operators _ =
  let expected =
"IDF a null (line 1, col 1)
PLUS + null (line 1, col 3)
IDF b null (line 1, col 5)
END  null (line 1, col 6)
"
  in
  assert_equal ~printer expected (tok "a + b")

let test_comparison _ =
  let expected =
"IDF x null (line 1, col 1)
EQ == null (line 1, col 3)
IDF y null (line 1, col 6)
END  null (line 1, col 7)
"
  in
  assert_equal ~printer expected (tok "x == y")

let test_dsl_keywords _ =
  let expected =
"NFA NFA null (line 1, col 1)
STATES states null (line 1, col 5)
LEFT_CURL { null (line 1, col 12)
IDF q0 null (line 1, col 13)
COMMA , null (line 1, col 15)
IDF q1 null (line 1, col 16)
RIGHT_CURL } null (line 1, col 18)
END  null (line 1, col 19)
"
  in
  assert_equal ~printer expected (tok "NFA states {q0,q1}")

let test_comment _ =
  let expected =
"VAR var null (line 1, col 1)
IDF x null (line 1, col 5)
ASSIGN = null (line 1, col 7)
INT 10 10 (line 1, col 9)
END  null (line 1, col 21)
"
  in
  assert_equal ~printer expected (tok "var x = 10 # comment")

(* -------- SUITE -------- *)

let suite =
  "Tokenizer Tests" >::: [
    "basic" >:: test_basic;
    "if" >:: test_if;
    "arrow" >:: test_arrow;
    "string" >:: test_string;
    "operators" >:: test_operators;
    "comparison" >:: test_comparison;
    "dsl keywords" >:: test_dsl_keywords;
    "comment" >:: test_comment;
  ]

let () =
  run_test_tt_main suite
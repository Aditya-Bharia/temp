open OUnit2
open Tokenizer
open Parser
open Ast

(* ---------- Helpers ---------- *)

let to_chars s = List.init (String.length s) (String.get s)

let parse_string s =
  s |> to_chars |> tokenize |> parse

let expect_fail s =
  try
    let _ = parse_string s in
    assert_failure ("Expected parse failure: " ^ s)
  with _ -> ()

(* ---------- BASIC EXPRESSIONS ---------- *)

let test_int _ =
  match parse_string "10" with
  | [ExprStmt (IntLit 10)] -> ()
  | _ -> assert_failure "Expected IntLit 10"

let test_string _ =
  match parse_string "\"hi\"" with
  | [ExprStmt (StrLit "hi")] -> ()
  | _ -> assert_failure "Expected string"

let test_bool _ =
  match parse_string "true" with
  | [ExprStmt (BoolLit true)] -> ()
  | _ -> assert_failure "Expected bool"

let test_variable _ =
  match parse_string "x" with
  | [ExprStmt (Var ("x", _))] -> ()
  | _ -> assert_failure "Expected variable"

(* ---------- BINARY EXPRESSIONS ---------- *)

let test_add _ =
  match parse_string "1 + 2" with
  | [ExprStmt (Binop (Add, IntLit 1, IntLit 2))] -> ()
  | _ -> assert_failure "Expected addition"

let test_precedence _ =
  match parse_string "1 + 2 * 3" with
  | [ExprStmt (Binop (Add, IntLit 1,
        Binop (Mul, IntLit 2, IntLit 3)))] -> ()
  | _ -> assert_failure "Precedence failed"

let test_parentheses _ =
  match parse_string "(1 + 2) * 3" with
  | [ExprStmt (Binop (Mul,
        Binop (Add, IntLit 1, IntLit 2),
        IntLit 3))] -> ()
  | _ -> assert_failure "Parentheses failed"

(* ---------- VAR DECL ---------- *)

let test_var_decl _ =
  match parse_string "var x = 10" with
  | [VarDecl ("x", IntLit 10, _)] -> ()
  | _ -> assert_failure "Expected var decl"

(* ---------- PRINT ---------- *)

let test_print _ =
  match parse_string "print(5)" with
  | [Print (IntLit 5, _)] -> ()
  | _ -> assert_failure "Expected print"

(* ---------- IF / WHILE ---------- *)

let test_if _ =
  match parse_string "if true { var x = 1 }" with
  | [If (BoolLit true, [VarDecl ("x", IntLit 1, _)], None, _)] -> ()
  | _ -> assert_failure "Expected if"

let test_if_else _ =
  match parse_string "if true { var x = 1 } else { var y = 2 }" with
  | [If (_, _, Some [VarDecl ("y", IntLit 2, _)], _)] -> ()
  | _ -> assert_failure "Expected if-else"

let test_while _ =
  match parse_string "while true { break }" with
  | [While (BoolLit true, [Break _], _)] -> ()
  | _ -> assert_failure "Expected while"

(* ---------- FUNCTION ---------- *)

let test_fn _ =
  match parse_string "fn f(x,y){ return x }" with
  | [FnDecl ("f", ["x"; "y"], _, _)] -> ()
  | _ -> assert_failure "Expected function"

(* ---------- NESTED ---------- *)

let test_nested _ =
  match parse_string "while true { if true { break } }" with
  | [While (_, [If (_, _, _, _)], _)] -> ()
  | _ -> assert_failure "Expected nested structure"

(* ---------- MULTI ---------- *)

let test_multiple _ =
  match parse_string "var x = 1 var y = 2" with
  | [VarDecl ("x", _, _); VarDecl ("y", _, _)] -> ()
  | _ -> assert_failure "Expected multiple statements"

(* ===================================================== *)
(* ================== DSL TESTS ========================= *)
(* ===================================================== *)

let test_full_nfa _ =
  match parse_string
    "NFA M {
       states {q0,q1}
       alphabet {a,b}
       start q0
       final {q1}
       transition {q0 a q1}
     }"
  with
  | [_] -> ()
  | _ -> assert_failure "Expected full NFA"

let test_dfa _ =
  match parse_string
    "DFA M {
       states {q0}
       alphabet {a}
       start q0
       final {q0}
     }"
  with
  | [_] -> ()
  | _ -> assert_failure "Expected DFA"
(* ---------- DSL OPERATIONS ---------- *)

let test_union _ =
  match parse_string "union(1,2)" with
  | [ExprStmt _] -> ()
  | _ -> assert_failure "Expected union"

let test_intersection _ =
  match parse_string "intersection(1,2)" with
  | [ExprStmt _] -> ()
  | _ -> assert_failure "Expected intersection"

let test_complement _ =
  match parse_string "complement(1)" with
  | [ExprStmt _] -> ()
  | _ -> assert_failure "Expected complement"

(* ---------- DSL ANALYSIS ---------- *)

let test_accepts _ =
  match parse_string "accepts(x,\"ab\")" with
  | [ExprStmt _] -> ()
  | _ -> assert_failure "Expected accepts"

let test_subset _ =
  match parse_string "subset(a,b)" with
  | [ExprStmt _] -> ()
  | _ -> assert_failure "Expected subset"

(* ---------- ERROR CASES ---------- *)

let test_invalid_var _ =
  expect_fail "var = 10"

let test_invalid_if _ =
  expect_fail "if { var x = 1 }"

let test_invalid_paren _ =
  expect_fail "(1 + 2"

let test_invalid_fn _ =
  expect_fail "fn (x){ return x }"

let test_invalid_transition _ =
  expect_fail "transition -> q1"

(* ---------- SUITE ---------- *)

let suite =
  "Parser Tests" >::: [

    "int" >:: test_int;
    "string" >:: test_string;
    "bool" >:: test_bool;
    "variable" >:: test_variable;

    "add" >:: test_add;
    "precedence" >:: test_precedence;
    "parentheses" >:: test_parentheses;

    "var" >:: test_var_decl;
    "print" >:: test_print;

    "if" >:: test_if;
    "if else" >:: test_if_else;
    "while" >:: test_while;

    "fn" >:: test_fn;

    "nested" >:: test_nested;
    "multiple" >:: test_multiple;

    "full nfa" >:: test_full_nfa;
    "dfa" >:: test_dfa;

    "union" >:: test_union;
    "intersection" >:: test_intersection;
    "complement" >:: test_complement;

    "accepts" >:: test_accepts;
    "subset" >:: test_subset;

    "invalid var" >:: test_invalid_var;
    "invalid if" >:: test_invalid_if;
    "invalid paren" >:: test_invalid_paren;
    "invalid fn" >:: test_invalid_fn;
    "invalid transition" >:: test_invalid_transition;
  ]

let () =
  run_test_tt_main suite
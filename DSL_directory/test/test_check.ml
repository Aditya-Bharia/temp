open OUnit2
open Tokenizer
open Parser
open Check

(* ---------- Helpers ---------- *)

let to_chars s = List.init (String.length s) (String.get s)

let run_check s =
  match s |> to_chars |> tokenize |> parse |> check with
  | Ok -> ()
  | Errors _ ->
      assert_failure "Unexpected errors"

let expect_fail s =
  match s |> to_chars |> tokenize |> parse |> check with
  | Ok -> assert_failure ("Expected failure: " ^ s)
  | Errors _ -> ()
(* ---------- BASIC VALID ---------- *)

let test_valid_var _ =
  run_check "var x = 10"

let test_valid_expr _ =
  run_check "var x = 1 + 2 * 3"

let test_valid_if _ =
  run_check "if true { var x = 1 }"

let test_valid_while _ =
  run_check "while true { break }"

let test_valid_fn _ =
  run_check "fn f(x){ return x }"

(* ---------- CONTROL FLOW CHECKS ---------- *)

let test_return_inside_fn _ =
  run_check "fn f(){ return 10 }"

let test_break_inside_loop _ =
  run_check "while true { break }"

let test_continue_inside_loop _ =
  run_check "while true { continue }"

(* ---------- ERROR CASES ---------- *)

let test_undef_var _ =
  expect_fail "x"

let test_redeclare _ =
  expect_fail "var x = 1 var x = 2"

let test_return_outside _ =
  expect_fail "return 10"

let test_break_outside _ =
  expect_fail "break"

let test_continue_outside _ =
  expect_fail "continue"

(* ---------- DSL AUTOMATA ---------- *)

let test_valid_nfa _ =
  run_check
    "NFA M {
       states {q0,q1}
       alphabet {a,b}
       start q0
       final {q1}
     }"

let test_missing_start _ =
  expect_fail
    "NFA M {
       states {q0,q1}
       final {q1}
     }"

let test_invalid_start _ =
  expect_fail
    "NFA M {
       states {q0,q1}
       start q2
     }"

let test_valid_transition _ =
  run_check
    "NFA M {
       states {q0,q1}
       start q0
       final {q1}
       transition q0 a q1
     }"

(* ---------- DSL OPERATIONS ---------- *)

let test_union _ =
  run_check "union(x,y)"

let test_intersection _ =
  run_check "intersection(x,y)"

let test_complement _ =
  run_check "complement(x)"

let test_invalid_union _ =
  expect_fail "union(x)"

(* ---------- DSL ANALYSIS ---------- *)

let test_accepts _ =
  run_check "accepts(x,\"ab\")"

let test_subset _ =
  run_check "subset(a,b)"

let test_equivalent _ =
  run_check "equivalent(a,b)"

let test_invalid_accepts _ =
  expect_fail "accepts(1,2)"

(* ---------- STRING / LIST ---------- *)

let test_string_ops _ =
  run_check "reverse(\"abc\")"

let test_concat _ =
  run_check "concat(\"a\",\"b\")"

let test_list _ =
  run_check "[1,2,3]"

(* ---------- COMPLEX PROGRAM ---------- *)

let test_full_program _ =
  run_check
    "
    var x = 10
    NFA M {
      states {q0,q1}
      start q0
      final {q1}
    }
    print(x)
    "

(* ---------- SUITE ---------- *)

let suite =
  "Check Tests" >::: [

    (* valid *)
    "valid var" >:: test_valid_var;
    "valid expr" >:: test_valid_expr;
    "valid if" >:: test_valid_if;
    "valid while" >:: test_valid_while;
    "valid fn" >:: test_valid_fn;

    (* control *)
    "return inside" >:: test_return_inside_fn;
    "break inside" >:: test_break_inside_loop;
    "continue inside" >:: test_continue_inside_loop;

    (* errors *)
    "undef var" >:: test_undef_var;
    "redeclare" >:: test_redeclare;
    "return outside" >:: test_return_outside;
    "break outside" >:: test_break_outside;
    "continue outside" >:: test_continue_outside;

    (* DSL automata *)
    "valid nfa" >:: test_valid_nfa;
    "missing start" >:: test_missing_start;
    "invalid start" >:: test_invalid_start;
    "valid transition" >:: test_valid_transition;

    (* DSL ops *)
    "union" >:: test_union;
    "intersection" >:: test_intersection;
    "complement" >:: test_complement;
    "invalid union" >:: test_invalid_union;

    (* DSL analysis *)
    "accepts" >:: test_accepts;
    "subset" >:: test_subset;
    "equivalent" >:: test_equivalent;
    "invalid accepts" >:: test_invalid_accepts;

    (* misc *)
    "string ops" >:: test_string_ops;
    "concat" >:: test_concat;
    "list" >:: test_list;

    (* integration *)
    "full program" >:: test_full_program;
  ]

let () =
  run_test_tt_main suite
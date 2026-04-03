open Ast
open Codegen
open OUnit2

let dp = dummy_pos

let tests =
  "test suite for codegen"
  >::: [

    ( "intlit" >:: fun _ ->
      assert_equal "0" (emit_expr (IntLit 0));
      assert_equal "42" (emit_expr (IntLit 42));
      assert_equal "-7" (emit_expr (IntLit (-7))) );

    ( "strlit" >:: fun _ ->
      assert_equal "\"\"" (emit_expr (StrLit ""));
      assert_equal "\"hello\"" (emit_expr (StrLit "hello"));
      assert_equal "\"say \\\"hi\\\"\"" (emit_expr (StrLit "say \"hi\"")) );

    ( "boollit emits Python casing" >:: fun _ ->
      assert_equal "True" (emit_expr (BoolLit true));
      assert_equal "False" (emit_expr (BoolLit false)) );

    ( "listlit" >:: fun _ ->
      assert_equal "[]" (emit_expr (ListLit []));
      assert_equal "[1, 2, 3]" (emit_expr (ListLit [IntLit 1; IntLit 2; IntLit 3])) );

    ( "var" >:: fun _ ->
      assert_equal "x" (emit_expr (Var ("x", dp)));
      assert_equal "myVar" (emit_expr (Var ("myVar", dp))) );

    ( "binop" >:: fun _ ->
      assert_equal "(1 + 2)" (emit_expr (Binop (Add, IntLit 1, IntLit 2)));
      assert_equal "(10 // 3)" (emit_expr (Binop (Div, IntLit 10, IntLit 3)));
      assert_equal "(True and False)" (emit_expr (Binop (And_placeholder, BoolLit true, BoolLit false)));
      assert_equal "(False or True)" (emit_expr (Binop (Or_placeholder, BoolLit false, BoolLit true)));
      assert_equal "((2 * 3) + 4)" (emit_expr (Binop (Add, Binop (Mul, IntLit 2, IntLit 3), IntLit 4))) );

    ( "unop" >:: fun _ ->
      assert_equal "(-5)" (emit_expr (Unop (Neg, IntLit 5)));
      assert_equal "(not True)" (emit_expr (Unop (Not, BoolLit true)));
      assert_equal "(-(-3))" (emit_expr (Unop (Neg, Unop (Neg, IntLit 3)))) );

    ( "assign as expr uses walrus" >:: fun _ ->
      assert_equal "(x := 5)" (emit_expr (Assign ("x", IntLit 5, dp))) );

    ( "assign as stmt uses plain equals not walrus" >:: fun _ ->
      assert_equal "x = 5" (emit_stmt 0 (ExprStmt (Assign ("x", IntLit 5, dp)))) );

    ( "index and call" >:: fun _ ->
      assert_equal "xs[0]" (emit_expr (Index (Var ("xs", dp), IntLit 0)));
      assert_equal "f()" (emit_expr (Call (Var ("f", dp), [])));
      assert_equal "f(1, \"a\")" (emit_expr (Call (Var ("f", dp), [IntLit 1; StrLit "a"])));
      assert_equal "g(f(0))" (emit_expr (Call (Var ("g", dp), [Call (Var ("f", dp), [IntLit 0])]))) );

    ( "language operations" >:: fun _ ->
      assert_equal "union(A, B)" (emit_expr (Union (Var ("A", dp), Var ("B", dp))));
      assert_equal "intersection(A, B)" (emit_expr (Intersection (Var ("A", dp), Var ("B", dp))));
      assert_equal "difference(A, B)" (emit_expr (Difference (Var ("A", dp), Var ("B", dp))));
      assert_equal "complement(A)" (emit_expr (Complement (Var ("A", dp), dp)));
      assert_equal "concat_lang(A, B)" (emit_expr (ConcatLang (Var ("A", dp), Var ("B", dp))));
      assert_equal "kleene_star(A)" (emit_expr (KleeneStar (Var ("A", dp))));
      assert_equal "kleene_plus(A)" (emit_expr (KleenePlus (Var ("A", dp))));
      assert_equal "reverse_lang(A)" (emit_expr (ReverseLang (Var ("A", dp))));
      assert_equal "kleene_star(union(A, B))"
        (emit_expr (KleeneStar (Union (Var ("A", dp), Var ("B", dp))))) );

    ( "transformations" >:: fun _ ->
      assert_equal "determinize(N)" (emit_expr (Determinize (Var ("N", dp))));
      assert_equal "minimize(N)" (emit_expr (Minimize (Var ("N", dp))));
      assert_equal "regex_to_nfa(r)" (emit_expr (RegexToNfa (Var ("r", dp))));
      assert_equal "nfa_to_regex(M)" (emit_expr (NfaToRegex (Var ("M", dp))));
      assert_equal "dfa_to_regex(D)" (emit_expr (DfaToRegex (Var ("D", dp), dp)));
      assert_equal "minimize(determinize(N))"
        (emit_expr (Minimize (Determinize (Var ("N", dp))))) );

    ( "analysis" >:: fun _ ->
      assert_equal "accepts(M, \"ab\")" (emit_expr (Accepts (Var ("M", dp), StrLit "ab")));
      assert_equal "accepts(M, \"\")" (emit_expr (Accepts (Var ("M", dp), StrLit "")));
      assert_equal "trace(M, \"ab\")" (emit_expr (Trace (Var ("M", dp), StrLit "ab")));
      assert_equal "equivalent(A, B)" (emit_expr (Equivalent (Var ("A", dp), Var ("B", dp))));
      assert_equal "regex_equivalent(r1, r2)" (emit_expr (RegexEquiv (Var ("r1", dp), Var ("r2", dp))));
      assert_equal "validate(M)" (emit_expr (Validate (Var ("M", dp))));
      assert_equal "subset(A, B)" (emit_expr (Subset (Var ("A", dp), Var ("B", dp))));
      assert_equal "is_empty(A)" (emit_expr (IsEmpty (Var ("A", dp))));
      assert_equal "is_finite(A)" (emit_expr (IsFinite (Var ("A", dp))));
      assert_equal "is_minimal(D)" (emit_expr (IsMinimal (Var ("D", dp), dp)));
      assert_equal "is_deterministic(M)" (emit_expr (IsDeterministic (Var ("M", dp))));
      assert_equal "reachable(M)" (emit_expr (Reachable (Var ("M", dp))));
      assert_equal "dead_states(M)" (emit_expr (DeadStates (Var ("M", dp)))) );

    ( "string operations" >:: fun _ ->
      assert_equal "str_reverse(s)" (emit_expr (Reverse (Var ("s", dp))));
      assert_equal "str_concat(s1, s2)" (emit_expr (ConcatStr (Var ("s1", dp), Var ("s2", dp))));
      assert_equal "chars(\"abc\")" (emit_expr (Chars (StrLit "abc")));
      assert_equal "random_str(5, \"ab\")" (emit_expr (RandomStr (IntLit 5, StrLit "ab"))) );

    ( "import" >:: fun _ ->
      assert_equal "import_automaton(\"machine.json\")" (emit_expr (Import ("machine.json", dp))) );

    ( "automaton def DFA" >:: fun _ ->
      let body = { kind = DFA; name = "D"; states = ["q0"; "q1"]; alphabet = ["a"];
        start = "q0"; final_states = ["q1"];
        transitions = [{ from_state = "q0"; on_symbol = Sym "a"; to_state = "q1"; pos = dp }];
        pos = dp } in
      let expected = "Automaton(\"DFA\", \"D\", [\"q0\", \"q1\"], [\"a\"], \"q0\", [\"q1\"], {\"q0\": {\"a\": [\"q1\"]}})" in
      assert_equal expected (emit_automaton_def body) );

    ( "automaton def NFA with epsilon" >:: fun _ ->
      let body = { kind = NFA; name = "N"; states = ["q0"; "q1"]; alphabet = [];
        start = "q0"; final_states = ["q1"];
        transitions = [{ from_state = "q0"; on_symbol = Eps; to_state = "q1"; pos = dp }];
        pos = dp } in
      let expected = "Automaton(\"NFA\", \"N\", [\"q0\", \"q1\"], [], \"q0\", [\"q1\"], {\"q0\": {\"eps\": [\"q1\"]}})" in
      assert_equal expected (emit_automaton_def body) );

    ( "automaton def merges nondeterministic transitions" >:: fun _ ->
      let body = { kind = NFA; name = "N"; states = ["q0"; "q1"; "q2"]; alphabet = ["a"];
        start = "q0"; final_states = ["q2"];
        transitions = [
          { from_state = "q0"; on_symbol = Sym "a"; to_state = "q1"; pos = dp };
          { from_state = "q0"; on_symbol = Sym "a"; to_state = "q2"; pos = dp }];
        pos = dp } in
      let expected = "Automaton(\"NFA\", \"N\", [\"q0\", \"q1\", \"q2\"], [\"a\"], \"q0\", [\"q2\"], {\"q0\": {\"a\": [\"q1\", \"q2\"]}})" in
      assert_equal expected (emit_automaton_def body) );

    ( "vardecl" >:: fun _ ->
      assert_equal "x = 5" (emit_stmt 0 (VarDecl ("x", IntLit 5, dp)));
      assert_equal "    x = 5" (emit_stmt 1 (VarDecl ("x", IntLit 5, dp))) );

    ( "fndecl" >:: fun _ ->
      assert_equal "def foo():\n    return" (emit_stmt 0 (FnDecl ("foo", [], [Return (None, dp)], dp)));
      assert_equal "def add(a, b):\n    return (a + b)"
        (emit_stmt 0 (FnDecl ("add", ["a"; "b"],
          [Return (Some (Binop (Add, Var ("a", dp), Var ("b", dp))), dp)], dp)));
      assert_equal "def noop():\n    pass" (emit_stmt 0 (FnDecl ("noop", [], [], dp))) );

    ( "automaton decl as stmt assigns to name" >:: fun _ ->
      let body = { kind = DFA; name = "D"; states = ["q0"]; alphabet = ["a"];
        start = "q0"; final_states = ["q0"];
        transitions = [{ from_state = "q0"; on_symbol = Sym "a"; to_state = "q0"; pos = dp }];
        pos = dp } in
      assert_equal "D = " (String.sub (emit_stmt 0 (AutomatonDecl body)) 0 4);
      assert_equal "    D = " (String.sub (emit_stmt 1 (AutomatonDecl body)) 0 8) );

    ( "if" >:: fun _ ->
      assert_equal "if True:\n    return" (emit_stmt 0 (If (BoolLit true, [Return (None, dp)], None, dp)));
      assert_equal "if True:\n    return 1\nelse:\n    return 0"
        (emit_stmt 0 (If (BoolLit true,
          [Return (Some (IntLit 1), dp)],
          Some [Return (Some (IntLit 0), dp)], dp)));
      assert_equal "if True:\n    pass" (emit_stmt 0 (If (BoolLit true, [], None, dp))) );

    ( "while" >:: fun _ ->
      assert_equal "while True:\n    break" (emit_stmt 0 (While (BoolLit true, [Break dp], dp)));
      assert_equal "while True:\n    pass" (emit_stmt 0 (While (BoolLit true, [], dp))) );

    ( "for" >:: fun _ ->
      assert_equal "for x in [1, 2]:\n    dsl_print(x)"
        (emit_stmt 0 (For ("x", ListLit [IntLit 1; IntLit 2], [Print (Var ("x", dp), dp)], dp)));
      assert_equal "for i in xs:\n    pass" (emit_stmt 0 (For ("i", Var ("xs", dp), [], dp))) );

    ( "break and continue" >:: fun _ ->
      assert_equal "break" (emit_stmt 0 (Break dp));
      assert_equal "    break" (emit_stmt 1 (Break dp));
      assert_equal "continue" (emit_stmt 0 (Continue dp)) );

    ( "return" >:: fun _ ->
      assert_equal "return" (emit_stmt 0 (Return (None, dp)));
      assert_equal "return 42" (emit_stmt 0 (Return (Some (IntLit 42), dp))) );

    ( "print uses dsl_print" >:: fun _ ->
      assert_equal "dsl_print(x)" (emit_stmt 0 (Print (Var ("x", dp), dp)));
      assert_equal "    dsl_print(x)" (emit_stmt 1 (Print (Var ("x", dp), dp))) );

    ( "visualize table stats export" >:: fun _ ->
      assert_equal "visualize(M)" (emit_stmt 0 (Visualize (Var ("M", dp), dp)));
      assert_equal "table(M)" (emit_stmt 0 (Table (Var ("M", dp), dp)));
      assert_equal "stats(M)" (emit_stmt 0 (Stats (Var ("M", dp), dp)));
      assert_equal "export(M, \"out.png\")" (emit_stmt 0 (Export (Var ("M", dp), "out.png", dp))) );

    ( "append and remove use underscore prefix" >:: fun _ ->
      assert_equal "_append(xs, 1)" (emit_stmt 0 (Append (Var ("xs", dp), IntLit 1, dp)));
      assert_equal "_remove(xs, 0)" (emit_stmt 0 (Remove (Var ("xs", dp), IntLit 0, dp))) );

    ( "program" >:: fun _ ->
      assert_equal "from runtime import *\n\nx = 1\n"
        (emit_program [VarDecl ("x", IntLit 1, dp)]) );

  ]

let _ = run_test_tt_main tests
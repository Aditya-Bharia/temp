open OUnit2

let test_dummy _ = assert_equal 1 1
let suite = "AutomataGen tests" >::: [ "dummy test" >:: test_dummy ]
let () = run_test_tt_main suite

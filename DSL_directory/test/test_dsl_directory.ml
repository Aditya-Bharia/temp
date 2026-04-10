open OUnit2

(*Helper Fuctions*)

let lib_dir = "../lib"

let file_exists_in_lib filename =
  Sys.file_exists (Filename.concat lib_dir filename)

(*Required.ml files*)

let required_ml_files =
  [ "ast.ml"; "check.ml"; "codegen.ml"; "dsl_directory.ml"; "my_utils.ml"; "parser.ml"; "tokenizer.ml"]


let is_present filename =
  let test_name = Printf.sprintf "%s exists in lib/" filename in
  test_name >:: fun _ ->
    let exists = file_exists_in_lib filename in
    let msg =
      Printf.sprintf
        "Required file '%s' not found in '%s'" filename lib_dir
    in
    assert_bool msg exists

let presence_tests =
  List.map is_present required_ml_files


let () = run_test_tt_main ("presence_tests" >::: presence_tests)

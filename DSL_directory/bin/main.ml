open My_utils
open Tokenizer

let usage () =
  prerr_endline "Usage: dune exec dsl_directory -- <program.agen> [--tokens] [--emit-only]";
  prerr_endline "  --tokens     print lexer output before parsing";
  prerr_endline "  --emit-only  only emit generated Python; do not execute"

let runtime_dir_candidates input_file =
  let cwd = Sys.getcwd () in
  let input_dir = Filename.dirname input_file in
  [ Filename.concat (Filename.dirname cwd) "python";
    Filename.concat cwd "python";
    Filename.concat input_dir "../python" ]

let find_runtime_dir input_file =
  let rec first_existing = function
    | [] -> None
    | dir :: rest ->
        if Sys.file_exists (Filename.concat dir "runtime.py") then Some dir
        else first_existing rest
  in
  first_existing (runtime_dir_candidates input_file)

let prepend_pythonpath dir =
  let old =
    try Sys.getenv "PYTHONPATH" with
    | Not_found -> ""
  in
  let value =
    if old = "" then dir else dir ^ ":" ^ old
  in
  Unix.putenv "PYTHONPATH" value

let write_python_file input_file py_code =
  let base = Filename.remove_extension (Filename.basename input_file) in
  let out_file = Filename.concat "/tmp" (base ^ ".generated.py") in
  Out_channel.with_open_text out_file (fun oc -> output_string oc py_code);
  out_file

let () =
  let args = Array.to_list Sys.argv |> List.tl in
  let show_tokens = List.exists (( = ) "--tokens") args in
  let emit_only = List.exists (( = ) "--emit-only") args in
  let file_args = List.filter (fun a -> a <> "--tokens" && a <> "--emit-only") args in
  match file_args with
  | [input_file] ->
      let source = read_file input_file in
      let tokens = tokenize (explode source) in
      if show_tokens then print_endline (print_tokens tokens);
      let prog = Parser.parse tokens in
      let result = Check.check prog in
      (match result with
       | Check.Ok ->
           print_endline "Semantic check passed - executing program...";
           let py_code = Codegen.emit_program prog in
           let py_file = write_python_file input_file py_code in
           if emit_only then
             Printf.printf "Generated Python written to: %s\n" py_file
           else
             (match find_runtime_dir input_file with
              | None ->
                  prerr_endline "Could not find python/runtime.py. Expected ../python/runtime.py from DSL_directory.";
                  exit 1
              | Some runtime_dir ->
                  prepend_pythonpath runtime_dir;
                  let cmd = Printf.sprintf "python3 %s" (Filename.quote py_file) in
                  let code = Sys.command cmd in
                  if code <> 0 then exit code)
       | Check.Errors _ as errs ->
           Check.print_result errs)
  | _ ->
      usage ();
      exit 1
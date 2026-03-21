let python_command =
  match Sys.getenv_opt "PYTHON" with
  | Some p -> p
  | None -> "python"

let run_python_script (script : string) : int =
  Sys.command (Printf.sprintf "%s %s" python_command script)

let () =
  let output = Interpreter.run [] in
  if String.length output > 0 then print_endline "interpreter test passed"
  else failwith "interpreter test failed"

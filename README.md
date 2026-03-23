# AutomataGen DSL

AutomataGen DSL is a starter scaffold for an OCaml-based domain specific language for defining and executing finite automata, with Python algorithms and tests.

## Structure
- lib: OCaml DSL library modules (tokenizer -> parser -> validator -> interpreter)
- bin: Executable entry point
- test: OCaml test executables and DSL test programs
- python: DFA/NFA algorithms and Python unit tests
- docs: specification and design documents
- examples: sample DSL programs

## Quick Start
1. Install OCaml + dune and Python 3.11+
2. Install Python deps:
   pip install -r requirements.txt
3. Run Python tests:
   pytest -q python/test_automata.py
4. Build OCaml executable:
   dune build
5. Run OCaml executable:
   dune exec automatagen-dsl
6. Run OCaml tests:
   dune runtest

## Notes
This scaffold includes placeholder parsing/interpreting logic to be expanded as the DSL grammar is finalized.

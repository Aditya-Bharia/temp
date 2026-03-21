# AutomataGen DSL

AutomataGen DSL is a starter scaffold for an OCaml-based domain specific language for defining and executing finite automata, with Python algorithms and tests.

## Structure
- src: OCaml DSL implementation pipeline (tokenizer -> parser -> validator -> interpreter)
- python: DFA/NFA algorithms and Python unit tests
- tests: OCaml test scaffolding and DSL test programs
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

## Notes
This scaffold includes placeholder parsing/interpreting logic to be expanded as the DSL grammar is finalized.

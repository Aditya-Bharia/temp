# AutomataGen DSL

AutomataGen is a domain-specific language for working with finite automata end to end: you can define NFAs/DFAs, transform them, verify language properties, and generate visual and machine-readable outputs.

The goal of this project is to make automata workflows practical and scriptable. Instead of manually writing one-off Python code for each experiment, you can express automata tasks in a compact DSL and run them as reproducible programs.

AutomataGen is useful for:

- learning and teaching automata concepts with executable examples
- rapidly prototyping formal-language ideas
- validating machines with semantic checks before runtime execution
- generating outputs (tables, stats, JSON, DOT, PNG) that are easy to inspect and share

The project uses a hybrid compilation/runtime pipeline:

- OCaml front-end for lexing, parsing, semantic checks, and code generation
- Python runtime for automata algorithms and visualization/export functionality

In short, write `.agen` programs, let the OCaml front-end validate and transpile them, and let the Python runtime execute the algorithms.

## What This DSL Supports

The language is intentionally broad. You can combine automata declarations, control flow, and automata operations in one program.

### Core capabilities

- Declare `NFA` and `DFA` machines with explicit states/alphabet/start/final/transitions
- Use epsilon transitions via `eps` in NFAs
- Compose machines with language operators (`union`, `intersection`, `difference`, etc.)
- Transform machines (`determinize`, `minimize`, regex conversions)
- Analyze behavior (`accepts`, `trace`, `equivalent`, `subset`, `is_empty`, etc.)
- Print tabular/statistical output and render/export machines (`table`, `stats`, `visualize`, `export`, `import`)
- Use regular programming constructs (`var`, `fn`, `if`, `while`, `for`, `return`, arithmetic, booleans, lists, indexing)

## Repository Layout

- `DSL_directory/`: OCaml compiler-like pipeline for the DSL
- `DSL_directory/lib/tokenizer.ml`: lexer
- `DSL_directory/lib/parser.ml`: recursive-descent parser
- `DSL_directory/lib/check.ml`: semantic checker
- `DSL_directory/lib/codegen.ml`: transpiler from DSL AST to Python
- `DSL_directory/bin/main.ml`: CLI runner (`dune exec dsl_directory -- ...`)
- `DSL_directory/source-code/`: sample `.agen` programs
- `DSL_directory/test/`: OCaml tests
- `python/runtime.py`: runtime library used by generated Python code
- `python/automata.py`: separate Python automata module
- `python/test_automata.py`: Python tests
- `docs/design.md`: high-level design notes

## End-to-End Execution Model

For a DSL input file:

1. Tokenize source text
2. Parse into AST
3. Run semantic checks
4. Generate Python code (`from runtime import *` + translated program)
5. Write generated file to `/tmp/<name>.generated.py`
6. Execute with `python3` (unless `--emit-only` is set)

CLI options:

- `--tokens`: print lexer output before parsing
- `--emit-only`: generate Python but do not execute it

## Setup

### Clone from GitHub

If you are starting from GitHub, use:

```bash
git clone https://github.com/<your-org-or-user>/AutomataGEN.git
cd AutomataGEN
```

Then install dependencies and run the DSL.

### Prerequisites

- OCaml + dune (project uses dune language 3.14)
- Python 3.11+
- Optional for visualization/export PNG: Graphviz system CLI (`dot`) and Python package `graphviz`

### Install dependencies

Recommended (PEP 668-safe): use a local virtual environment.

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
```

Install Graphviz system binaries if you want PNG exports:

```bash
# Ubuntu/Debian
sudo apt-get install graphviz
```

### One-command setup and build

From the project root, run:

```bash
bash setup.sh
```

This script will:

- auto-install system dependencies on apt-based Linux when missing: `python3-venv`, `python3-pip`, `ocaml`, `opam`, `graphviz`, `python3-graphviz`
- create a local virtual environment at `.venv`
- install Python dependencies from `requirements.txt` into `.venv`
- initialize opam and activate opam environment in-script
- install `dune` via opam if missing
- install OCaml dependencies via opam
- run `dune build bin/main.exe` inside `DSL_directory`

### Step-by-step: How to test setup.sh

Run these steps from a fresh terminal.

1. Go to project root.

```bash
cd ~/AutomataGEN
```

2. Run setup.

```bash
bash setup.sh
```

3. Verify required tools are available after setup.

```bash
python3 -m pip --version
opam --version
dune --version
dot -V
.venv/bin/python -m pip --version
```

4. Verify build artifact exists.

```bash
test -f DSL_directory/_build/default/bin/main.exe && echo "build ok"
```

5. Run sample DSL program.

```bash
cd DSL_directory
dune exec dsl_directory -- source-code/all_features.agen
```

6. Verify expected output files were generated.

```bash
test -f all_features.json && echo "json ok"
test -f all_features.png && echo "png ok"
test -f automaton.png && echo "visualize ok"
```

## Build and Run

From the project root:

```bash
cd DSL_directory
dune build bin/main.exe
```

Run a DSL program:

```bash
dune exec dsl_directory -- source-code/all_features.agen
```

Emit generated Python only:

```bash
dune exec dsl_directory -- source-code/all_features.agen --emit-only
```

Sample emitted output:

```text
Semantic check passed - executing program...
Generated Python written to: /tmp/all_features.generated.py
```

Run Python tests:

```bash
.venv/bin/pytest -q python/test_automata.py
```

Run OCaml tests:

```bash
cd DSL_directory
dune runtest
```

Note: full test runs require `ounit2` because test executables depend on it.

## Quickstart from Fresh Clone

Use this exact sequence on a clean machine:

```bash
# 1) Clone
git clone https://github.com/<your-org-or-user>/AutomataGEN.git
cd AutomataGEN

# 2) Python dependency (pytest) + optional graphviz Python package
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt

# 3) Optional system dependency for PNG rendering/export
sudo apt-get update
sudo apt-get install -y graphviz

# 4) Build DSL runner
cd DSL_directory
dune build bin/main.exe

# 5) Run sample DSL program
dune exec dsl_directory -- source-code/all_features.agen

# 6) (Optional) Emit generated Python only
dune exec dsl_directory -- source-code/all_features.agen --emit-only
```

If execution succeeds, you should see semantic-check output, stats/table output, and generated artifacts such as `all_features.json`, `all_features.png`, and `automaton.png` in `DSL_directory/`.

## DSL Syntax Overview

### Comments

- Line comment: `# comment`
- Block comment: `/* comment */`

### Automaton declaration

```agen
NFA M {
    states { q0, q1, q2 }
    alphabet { a, b }
    start q0
    final { q2 }

    transition {
        q0 a -> q0,
        q0 eps -> q1,
        q1 b -> q2,
        q2 b -> q2
    }
}
```

For `DFA`, epsilon transitions and nondeterministic duplicate `(state, symbol)` transitions are rejected by semantic checks.

### Statements and control flow

- Variable declaration: `var x = ...`
- Function declaration: `fn f(a, b) { ... }`
- If/else: `if cond { ... } else { ... }`
- While loop: `while cond { ... }`
- For-in loop: `for item in listExpr { ... }`
- `return`, `break`, `continue`

### Expressions

- Literals: integers, strings, booleans, lists
- Arithmetic: `+ - * /`
- Comparisons: `== != < <= > >=`
- Boolean: `and or not`
- Assignment expression: `x = expr`
- Indexing: `arr[i]`
- Function calls: `f(x, y)`

## Built-in Operations

### Language operations

- `union(A, B)`
- `intersection(A, B)`
- `difference(A, B)`
- `complement(A)`
- `concat_lang(A, B)`
- `kleene_star(A)`
- `kleene_plus(A)`
- `reverse_lang(A)`

### Transformations

- `determinize(M)`
- `minimize(M)`
- `regex_to_nfa(regex)`
- `nfa_to_regex(M)`
- `dfa_to_regex(D)`

### Analysis and checking

- `accepts(M, word)`
- `trace(M, word)`
- `equivalent(A, B)`
- `regex_equivalent(r1, r2)`
- `validate(M)`
- `subset(A, B)`
- `is_empty(M)`
- `is_finite(M)`
- `is_minimal(D)`
- `is_deterministic(M)`
- `reachable(M)`
- `dead_states(M)`

### I/O and artifacts

- `print(x)`
- `visualize(M)`
- `table(M)`
- `stats(M)`
- `export(M, "file.json|file.dot|file.png")`
- `import("file.json")`

### String/list helpers

- `reverse(s)`
- `concat(a, b)`
- `chars(s)`
- `random_str(length, alphabet)`
- `append(list, value)`
- `remove(list, index)`

## Real Program Example

This repository includes a complete sample at `DSL_directory/source-code/all_features.agen`.

Run:

```bash
cd DSL_directory
dune exec dsl_directory -- source-code/all_features.agen
```

Representative output:

```text
Semantic check passed - executing program...
[validate] 'D' - all checks passed.
semantic/runtime checks look good
abb: rejected
ab: accepted
bbb: rejected

[stats] DFA: D
  States        : 3
  Alphabet      : 2  (a, b)
  Accept states : 1
  Transitions   : 6
  Deterministic : True
  Empty language: False

[export] JSON -> all_features.json
[export] PNG -> all_features.png
[visualize] Saved -> automaton.png
```

The sample demonstrates:

- NFA/DFA declaration
- transformation and equivalence calls
- list/string manipulation
- `if`, `while`, `for`, `continue`, `break`
- transition tracing and diagnostics
- export/import and visualization

## Output Image Example

Example rendered automaton output:

![AutomataGen output image](DSL_directory/all_features.png)

If the image is not present in your local clone, generate it by running:

```bash
cd DSL_directory
dune exec dsl_directory -- source-code/all_features.agen
```

This creates `DSL_directory/all_features.png` via the DSL `export(..., "all_features.png")` call in the sample program.

## Example: Transition Table Output

Calling `table(M)` prints a formatted transition table. Example shape:

```text
  DFA: M_det_min
  ==========================
  State        a       b
  --------------------------
   *q0         -       q0
  -> q1        q1      q0
```

Legend:

- `->` start state
- `*` accept state
- `-` missing transition

## Semantic Checker Behavior

The checker catches name and automaton consistency errors before Python execution.

Examples of checks:

- use of undeclared variables/functions
- duplicate declarations and reserved/builtin name redefinition
- invalid automaton shape (unknown states/symbols, duplicate DFA transitions, epsilon in DFA)
- illegal control flow (`break` outside loop, `return` outside function)
- DFA-only function misuse on NFA in selected operations (`complement`, `dfa_to_regex`, `is_minimal`)

Failure output format:

```text
Semantic check failed with N error(s):
  [1] line X col Y: ...
  [2] line X col Y: ...
```

## Output Artifacts

Generated assets depend on your DSL program:

- generated Python source: `/tmp/<input>.generated.py`
- visualization image: `automaton.png` by default from `visualize(...)`
- export files: JSON/DOT/PNG based on target extension

## Current Practical Notes

- `visualize()` requires Python package `graphviz`
- PNG export via `export(..., ".png")` requires Graphviz CLI (`dot`)
- Runner auto-configures `PYTHONPATH` to find `python/runtime.py`
- Checker expects automata arguments to many language ops as references (variables), which is why samples assign intermediate results before reuse

## Quick Command Reference

```bash
# Build executable
cd DSL_directory && dune build bin/main.exe

# Run sample program
cd DSL_directory && dune exec dsl_directory -- source-code/all_features.agen

# Emit generated Python only
cd DSL_directory && dune exec dsl_directory -- source-code/all_features.agen --emit-only

# Show lexer tokens while running
cd DSL_directory && dune exec dsl_directory -- source-code/all_features.agen --tokens

# Python tests
.venv/bin/pytest -q python/test_automata.py
```

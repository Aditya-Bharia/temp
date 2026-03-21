# AutomataGen DSL design notes

- Goal: define a concise DSL to declare automata and run acceptance checks.
- Pipeline: tokenize -> parse -> validate -> interpret.
- Python bridge: invoke DFA/NFA helpers for advanced algorithms.

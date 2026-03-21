from automata import DFA, NFA


def test_dfa_accepts_binary_ending_in_1():
    dfa = DFA(
        states={"q0", "q1"},
        alphabet={"0", "1"},
        transition={
            ("q0", "0"): "q0",
            ("q0", "1"): "q1",
            ("q1", "0"): "q0",
            ("q1", "1"): "q1",
        },
        start_state="q0",
        accept_states={"q1"},
    )
    assert dfa.accepts("101") is True
    assert dfa.accepts("100") is False


def test_nfa_accepts_single_a():
    nfa = NFA(
        states={"s", "f"},
        alphabet={"a"},
        transition={("s", "a"): {"f"}},
        start_states={"s"},
        accept_states={"f"},
    )
    assert nfa.accepts("a") is True
    assert nfa.accepts("") is False

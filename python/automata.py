class DFA:
    def __init__(self, states, alphabet, transition, start_state, accept_states):
        self.states = set(states)
        self.alphabet = set(alphabet)
        self.transition = transition
        self.start_state = start_state
        self.accept_states = set(accept_states)

    def accepts(self, word: str) -> bool:
        state = self.start_state
        for ch in word:
            key = (state, ch)
            if key not in self.transition:
                return False
            state = self.transition[key]
        return state in self.accept_states


class NFA:
    def __init__(self, states, alphabet, transition, start_states, accept_states):
        self.states = set(states)
        self.alphabet = set(alphabet)
        self.transition = transition
        self.start_states = set(start_states)
        self.accept_states = set(accept_states)

    def accepts(self, word: str) -> bool:
        current = set(self.start_states)
        for ch in word:
            nxt = set()
            for state in current:
                nxt |= set(self.transition.get((state, ch), set()))
            current = nxt
            if not current:
                return False
        return len(current & self.accept_states) > 0

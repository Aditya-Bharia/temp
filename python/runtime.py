import json
import os
import random
import subprocess
from collections import defaultdict, deque
from graphviz import Digraph   # pip install graphviz is required for this to work

__all__ = [
    'NFA', 'DFA', 'Automaton',
    'union', 'intersection', 'difference', 'complement',
    'concat_lang', 'kleene_star', 'kleene_plus', 'reverse_lang',
    'determinize', 'minimize', 'regex_to_nfa', 'nfa_to_regex', 'dfa_to_regex',
    'accepts', 'trace', 'equivalent', 'regex_equivalent', 'validate',
    'subset', 'is_empty', 'is_finite', 'is_minimal', 'is_deterministic',
    'reachable', 'dead_states',
    'dsl_print', 'visualize', 'table', 'stats', 'export', 'import_automaton',
    'str_reverse', 'str_concat', 'chars', 'random_str',
    '_append', '_remove',
]

def regex_to_postfix(pattern: str) -> list:
    """Parses a regex string into a postfix list of (Type, Value) tokens."""
    if not pattern:
        return []
    tokens = []
    i = 0
    # Step 1: tokenize and handle escape characters
    while i < len(pattern):
        c = pattern[i]
        if c == '\\':
            if i + 1 < len(pattern):
                tokens.append(('LITERAL', pattern[i+1]))
                i += 2
            else:
                raise ValueError("Regex error: trailing backslash")
        elif c in {'*', '+', '?', '|', '(', ')'}:
            tokens.append(('OPERATOR', c))
            i += 1
        else:
            tokens.append(('LITERAL', c))
            i += 1
    # step 2: validate structure (catch obvious syntax errors early)
    for i, tok in enumerate(tokens):
        if tok[0] == 'OPERATOR' and tok[1] in {'*', '+', '?'}:
            if i == 0 or (tokens[i-1][0] == 'OPERATOR' and tokens[i-1][1] in {'|', '('}):
                raise ValueError(f"Regex error: '{tok[1]}' has nothing to apply to")
            if i > 0 and tokens[i-1][0] == 'OPERATOR' and tokens[i-1][1] in {'*', '+', '?'}:
                raise ValueError("Regex error: consecutive unary ops")
        elif tok[0] == 'OPERATOR' and tok[1] == '|':
            if i == 0 or (tokens[i-1][0] == 'OPERATOR' and tokens[i-1][1] in {'|', '('}):
                raise ValueError("Regex error: '|' missing left operand")
            if i + 1 == len(tokens) or (tokens[i+1][0] == 'OPERATOR' and tokens[i+1][1] in {'|', ')'}):
                raise ValueError("Regex error: '|' missing right operand")    
    depth = 0
    for i, tok in enumerate(tokens):
        if tok[0] == 'OPERATOR':
            if tok[1] == '(':
                depth += 1
                if i + 1 < len(tokens) and tokens[i+1][0] == 'OPERATOR' and tokens[i+1][1] == ')':
                    raise ValueError("Regex error: empty group '()' not allowed")
            elif tok[1] == ')':
                depth -= 1
                if depth < 0:
                    raise ValueError("Regex error: ')' has no matching '('")
    if depth != 0:
        raise ValueError("Regex error: unclosed parenthesis(es)")
    # step 3: insert explicit concat operators where needed
    explicit = []
    for i, tok in enumerate(tokens):
        explicit.append(tok)
        if i + 1 < len(tokens):
            nxt = tokens[i+1]
            left_ok = tok[0] == 'LITERAL' or (tok[0] == 'OPERATOR' and tok[1] in {'*', '+', '?', ')'})
            right_ok = nxt[0] == 'LITERAL' or (nxt[0] == 'OPERATOR' and nxt[1] == '(')
            if left_ok and right_ok:
                explicit.append(('OPERATOR', 'CONCAT'))
    # step 4: classic shunting-yard algorithm to get postfix notation
    prec = {'|': 1, 'CONCAT': 2, '*': 3, '+': 3, '?': 3}
    output = []
    stack = []
    for typ, val in explicit:
        if typ == 'LITERAL':
            output.append((typ, val))
        elif val == '(':
            stack.append((typ, val))
        elif val == ')':
            while stack and stack[-1][1] != '(':
                output.append(stack.pop())
            stack.pop() # discard '('
        else:
            while stack and stack[-1][1] != '(' and prec.get(stack[-1][1], 0) >= prec.get(val, 0):
                output.append(stack.pop())
            stack.append((typ, val))
    while stack:
        output.append(stack.pop())
    return output

class NFA:
    def __init__(self, pattern=None, *,
                 states=None, alphabet=None, transitions=None,
                 start=None, accept=None):
        if any(x is not None for x in [states, alphabet, transitions, start, accept]):
            if any(x is None for x in [states, alphabet, transitions, start, accept]):
                raise ValueError("NFA explicit mode: all five fields required")
            norm = {}
            for s, sym_map in transitions.items():
                norm[s] = {}
                for sym, tgts in sym_map.items():
                    norm[s][sym] = set(tgts) if isinstance(tgts, (list, tuple, set)) else {tgts}
            self.states      = set(states)
            self.alphabet    = set(alphabet)
            self.transitions = norm
            self.start       = start
            self.accept      = set(accept)
            return
        if pattern is None:
            raise TypeError("NFA() needs a regex pattern or explicit components")
        if not isinstance(pattern, str):
            raise TypeError(f"NFA pattern must be a string, got {type(pattern)}")
        postfix      = regex_to_postfix(pattern)
        self._ctr    = 0

        def new():
            s = self._ctr; self._ctr += 1; return s

        def merge(*dicts):
            """Union-merge multiple transition dicts."""
            r = defaultdict(lambda: defaultdict(set))
            for d in dicts:
                for s, sm in d.items():
                    for sym, tgts in sm.items():
                        r[s][sym] |= tgts
            return r
        stack = []
        # handle the empty string regex edge case
        if not postfix:
            ns = new()
            self.start = ns
            self.accept = {ns}
            self.transitions = {ns: {}}
            self.states = {ns}
            self.alphabet = set()
            return
        # build the nfa using Thompson's construction
        for typ, val in postfix:
            if typ == 'OPERATOR':
                if val == '*':
                    s0, s1, tr = stack.pop()
                    ns, na = new(), new()
                    t = merge(tr)
                    t[ns]['ε'] |= {s0, na}   # skip or enter
                    t[s1]['ε'] |= {s0, na}   # loop or exit
                    stack.append((ns, na, t))
                elif val == '+':
                    s0, s1, tr = stack.pop()
                    ns, na = new(), new()
                    t = merge(tr)
                    t[ns]['ε'] |= {s0}        # must enter (no skip)
                    t[s1]['ε'] |= {s0, na}    # loop or exit
                    stack.append((ns, na, t))   
                elif val == '?':
                    s0, s1, tr = stack.pop()
                    ns, na = new(), new()
                    t = merge(tr)
                    t[ns]['ε'] |= {s0, na}    # enter or skip
                    t[s1]['ε'] |= {na}        # just exit
                    stack.append((ns, na, t))
                elif val == 'CONCAT':
                    s20, s21, tr2 = stack.pop()   # right operand
                    s10, s11, tr1 = stack.pop()   # left operand
                    t = merge(tr1, tr2)
                    t[s11]['ε'] |= {s20}
                    stack.append((s10, s21, t))
                elif val == '|':
                    s20, s21, tr2 = stack.pop()
                    s10, s11, tr1 = stack.pop()
                    ns, na = new(), new()
                    t = merge(tr1, tr2)
                    t[ns]['ε'] |= {s10, s20}
                    t[s11]['ε'] |= {na}
                    t[s21]['ε'] |= {na}
                    stack.append((ns, na, t))
            else:
                # basic literal character transition
                ns, na = new(), new()
                t = defaultdict(lambda: defaultdict(set))
                t[ns][val] |= {na}
                stack.append((ns, na, t))
        self.start, acc, raw = stack.pop()
        self.accept      = {acc}
        self.transitions = {s: dict(sm) for s, sm in raw.items()}
        self.states      = set(range(self._ctr))
        self.alphabet    = {sym for sm in self.transitions.values()
                            for sym in sm if sym != 'ε'}

class DFA:
    def __init__(self, source=None, *,
                 states=None, alphabet=None, transitions=None,
                 start=None, accept=None):
        if isinstance(source, DFA):
            self.__dict__.update(source.__dict__)
            return
        if any(x is not None for x in [states, alphabet, transitions, start, accept]):
            if any(x is None for x in [states, alphabet, transitions, start, accept]):
                raise ValueError("DFA explicit mode: all five fields required")
            dfa_t = {}
            for s, sm in transitions.items():
                dfa_t[s] = {}
                for sym, tgt in sm.items():
                    if isinstance(tgt, (list, set)):
                        if tgt: dfa_t[s][sym] = list(tgt)[0]
                    else:
                        dfa_t[s][sym] = tgt
            self.states = set(states)
            self.alphabet = set(alphabet)
            self.transitions = dfa_t
            self.start = start
            self.accept = set(accept)
            return
        elif source is None:
            raise TypeError("DFA() needs an NFA, regex string, or explicit components")
        elif isinstance(source, str):
            source = NFA(source)
        elif not isinstance(source, NFA):
            raise TypeError(f"DFA() expected NFA or str, got {type(source)}")
        nfa = source

        def eps_closure(states_set):
            closure = set(states_set)
            stk = list(states_set)
            while stk:
                s = stk.pop()
                for t in nfa.transitions.get(s, {}).get('ε', set()):
                    if t not in closure:
                        closure.add(t); stk.append(t)
            return frozenset(closure)

        def move(states_set, sym):
            result = set()
            for s in states_set:
                result |= nfa.transitions.get(s, {}).get(sym, set())
            return result

        #subset construction (powerset algorithm)
        self.alphabet = nfa.alphabet
        start_cl      = eps_closure({nfa.start})
        self.start    = start_cl
        self.states      = set()
        self.transitions = {}
        self.accept      = set()
        worklist = [start_cl]
        visited  = {start_cl}
        while worklist:
            cur = worklist.pop()
            self.states.add(cur)
            self.transitions[cur] = {}
            if cur & nfa.accept:
                self.accept.add(cur)
            for sym in self.alphabet:
                nxt = eps_closure(move(cur, sym))
                if not nxt:
                    continue
                self.transitions[cur][sym] = nxt
                if nxt not in visited:
                    visited.add(nxt); worklist.append(nxt)


class Automaton:
    def __init__(self, kind: str, name: str,
                 states: list, alphabet: list,
                 start: str, final: list,
                 transitions: dict):
        self.kind     = kind
        self.name     = name
        self._orig_states      = list(states)
        self._orig_alphabet    = list(alphabet)
        self._orig_start       = start
        self._orig_final       = list(final)
        self._orig_transitions = transitions  

        norm = {}
        for s, sym_map in transitions.items():
            norm[s] = {}
            for sym, tgts in sym_map.items():
                key = 'ε' if sym == 'eps' else sym
                norm[s][key] = set(tgts) if isinstance(tgts, (list, tuple, set)) else {tgts}

        if kind == "NFA":
            self._machine = NFA(
                states=set(states), alphabet=set(alphabet),
                transitions=norm, start=start, accept=set(final)
            )
        else:
            self._machine = DFA(
                states=set(states), alphabet=set(alphabet),
                transitions=norm, start=start, accept=set(final)
            )
            
    def __repr__(self):
        return f"<Automaton {self.kind} '{self.name}'>"

def _get_machine(obj):
    if isinstance(obj, Automaton): return obj._machine
    if isinstance(obj, (NFA, DFA)): return obj
    raise TypeError(f"Expected Automaton/NFA/DFA, got {type(obj)}")

def _wrap(machine, name="result") -> Automaton:
    #quick wrapper to return automaton objects to the dsl
    a = object.__new__(Automaton)
    a.kind              = "NFA" if isinstance(machine, NFA) else "DFA"
    a.name              = name
    a._machine          = machine
    a._orig_states      = []
    a._orig_alphabet    = []
    a._orig_start       = ""
    a._orig_final       = []
    a._orig_transitions = {}
    return a

def _to_nfa(m) -> NFA:
    if isinstance(m, NFA):
        return m
    nfa_t = {s: {sym: {tgt} for sym, tgt in trans.items()}
             for s, trans in m.transitions.items()}
    return NFA(states=set(m.states),
               alphabet=m.alphabet,
               transitions=nfa_t,
               start=m.start,
               accept=set(m.accept))

def _product_dfa(d1: DFA, d2: DFA, alphabet: set, accept_rule: str) -> DFA:
    #general-purpose product construction (used for union, intersection, etc)
    DEAD1, DEAD2 = -1, -2
    def n1(s, sym): return d1.transitions.get(s, {}).get(sym, DEAD1)
    def n2(s, sym): return d2.transitions.get(s, {}).get(sym, DEAD2)

    start = (d1.start, d2.start)
    sid   = {start: 0}
    wl    = [start]
    trans = defaultdict(dict)
    acc   = set()
    
    while wl:
        pair = wl.pop(0)
        s1, s2 = pair
        me = sid[pair]
        a1 = (s1 in d1.accept)
        a2 = (s2 in d2.accept)
        if   accept_rule == "and"  and a1 and a2:          acc.add(me)
        elif accept_rule == "or"   and (a1 or a2):         acc.add(me)
        elif accept_rule == "left" and a1 and not a2:      acc.add(me)
        elif accept_rule == "xor"  and (a1 != a2):         acc.add(me)
        for sym in alphabet:
            nx1 = n1(s1, sym) if s1 != DEAD1 else DEAD1
            nx2 = n2(s2, sym) if s2 != DEAD2 else DEAD2
            np  = (nx1, nx2)
            if np not in sid:
                sid[np] = len(sid); wl.append(np)
            trans[me][sym] = sid[np]
    result = object.__new__(DFA)
    result.alphabet    = alphabet
    result.start       = 0
    result.accept      = acc
    result.states      = set(trans.keys())
    result.transitions = {s: dict(t) for s, t in trans.items()}
    return result

def _complete(d: DFA, full_alpha: set) -> DFA:
    #send missing transitions to a dead state
    DEAD = -1
    t = defaultdict(dict)
    for s in d.states:  #use states to avoid dropping isolated states
        for sym in full_alpha:
            t[s][sym] = d.transitions.get(s, {}).get(sym, DEAD)
    for sym in full_alpha:
        t[DEAD][sym] = DEAD 
        
    result = object.__new__(DFA)
    result.alphabet    = full_alpha
    result.start       = d.start
    result.accept      = set(d.accept)
    result.states      = set(t.keys())
    result.transitions = {s: dict(v) for s, v in t.items()}
    return result

def _reachable_ids(d: DFA) -> set:
    visited  = {d.start}
    worklist = [d.start]
    while worklist:
        s = worklist.pop()
        for t in d.transitions.get(s, {}).values():
            if t not in visited:
                visited.add(t); worklist.append(t)
    return visited

def _ensure_dfa(obj) -> DFA:
    m = _get_machine(obj)
    return m if isinstance(m, DFA) else DFA(m)

def _rename_nfa(m: NFA, offset: int):
    #helps prevent state id collisions when merging nfas
    if not m.states:
        return m
    sample = next(iter(m.states))
    if isinstance(sample, int):
        remap = {s: s + offset for s in m.states}
    else:
        remap = {s: i + offset for i, s in enumerate(sorted(m.states, key=str))}
    new_trans = {}
    for s, sym_map in m.transitions.items():
        new_trans[remap[s]] = {}
        for sym, tgts in sym_map.items():
            new_trans[remap[s]][sym] = {remap[t] for t in tgts if t in remap}
    result          = object.__new__(NFA)
    result.states   = set(remap.values())
    result.alphabet = m.alphabet
    result.transitions = new_trans
    result.start    = remap[m.start]
    result.accept   = {remap[s] for s in m.accept}
    return result

def _combine(ma: NFA, mb: NFA):
    ma2 = _rename_nfa(ma, 0)
    mb2 = _rename_nfa(mb, len(ma2.states))
    return ma2, mb2

# language Operations
def union(A, B) -> Automaton:
    ma, mb = _combine(_to_nfa(_get_machine(A)), _to_nfa(_get_machine(B)))
    ns = len(ma.states) + len(mb.states) 
    trans = defaultdict(lambda: defaultdict(set))
    for s, sm in ma.transitions.items():
        for sym, tgts in sm.items(): trans[s][sym] |= tgts
    for s, sm in mb.transitions.items():
        for sym, tgts in sm.items(): trans[s][sym] |= trans[s][sym] | tgts
    trans[ns]['ε'] |= {ma.start, mb.start}
    result          = object.__new__(NFA)
    result.start    = ns
    result.accept   = ma.accept | mb.accept
    result.transitions = {s: dict(sm) for s, sm in trans.items()}
    result.states   = ma.states | mb.states | {ns}
    result.alphabet = ma.alphabet | mb.alphabet
    return _wrap(result, "union")

def intersection(A, B) -> Automaton:
    da = DFA(_get_machine(A))
    db = DFA(_get_machine(B))
    alpha = da.alphabet | db.alphabet
    da, db = _complete(da, alpha), _complete(db, alpha)
    return _wrap(_product_dfa(da, db, alpha, "and"), "intersection")

def difference(A, B) -> Automaton:
    da = DFA(_get_machine(A))
    db = DFA(_get_machine(B))
    alpha = da.alphabet | db.alphabet
    da, db = _complete(da, alpha), _complete(db, alpha)
    return _wrap(_product_dfa(da, db, alpha, "left"), "difference")

def complement(A) -> Automaton:
    d = DFA(_get_machine(A))
    d = _complete(d, d.alphabet)
    new_accept = set(d.states) - d.accept
    result = object.__new__(DFA)
    result.alphabet    = d.alphabet
    result.start       = d.start
    result.accept      = new_accept
    result.states      = set(d.states)
    result.transitions = {s: dict(t) for s, t in d.transitions.items()}
    return _wrap(result, "complement")

def concat_lang(A, B) -> Automaton:
    ma, mb = _combine(_to_nfa(_get_machine(A)), _to_nfa(_get_machine(B)))
    trans = defaultdict(lambda: defaultdict(set))
    for s, sm in ma.transitions.items():
        for sym, tgts in sm.items(): trans[s][sym] |= tgts
    for s, sm in mb.transitions.items():
        for sym, tgts in sm.items(): trans[s][sym] |= tgts
    for f in ma.accept:
        trans[f]['ε'].add(mb.start)
    result          = object.__new__(NFA)
    result.start    = ma.start
    result.accept   = mb.accept
    result.transitions = {s: dict(sm) for s, sm in trans.items()}
    result.states   = ma.states | mb.states
    result.alphabet = ma.alphabet | mb.alphabet
    return _wrap(result, "concat_lang")

def kleene_star(A) -> Automaton:
    ma  = _to_nfa(_get_machine(A))
    ma  = _rename_nfa(ma, 0)
    ns  = len(ma.states)
    trans = defaultdict(lambda: defaultdict(set))
    for s, sm in ma.transitions.items():
        for sym, tgts in sm.items(): trans[s][sym] |= tgts
    trans[ns]['ε'].add(ma.start)
    for f in ma.accept:
        trans[f]['ε'] |= {ma.start, ns}
    result          = object.__new__(NFA)
    result.start    = ns
    result.accept   = ma.accept | {ns}
    result.transitions = {s: dict(sm) for s, sm in trans.items()}
    result.states   = ma.states | {ns}
    result.alphabet = ma.alphabet
    return _wrap(result, "kleene_star")

def kleene_plus(A) -> Automaton:
    return concat_lang(A, kleene_star(A))

def reverse_lang(A) -> Automaton:
    ma  = _to_nfa(_get_machine(A))
    ma  = _rename_nfa(ma, 0)
    ns  = len(ma.states)
    trans = defaultdict(lambda: defaultdict(set))
    for s, sm in ma.transitions.items():
        for sym, tgts in sm.items():
            for t in tgts:
                trans[t][sym].add(s)
    trans[ns]['ε'] |= ma.accept
    result          = object.__new__(NFA)
    result.start    = ns
    result.accept   = {ma.start}
    result.transitions = {s: dict(sm) for s, sm in trans.items()}
    result.states   = ma.states | {ns}
    result.alphabet = ma.alphabet
    return _wrap(result, "reverse_lang")

def determinize(A) -> Automaton:
    m = _get_machine(A)
    d = DFA(m)
    return _wrap(d, (A.name + "_det") if isinstance(A, Automaton) else "det")

def minimize(A) -> Automaton:
    m = _get_machine(A)
    if isinstance(m, NFA):
        m = DFA(m)
    #strip unreachable states first so garbage doesn't mess up the partitions
    reach = _reachable_ids(m)
    m.states = reach
    m.accept = m.accept & reach
    non_acc = m.states - m.accept
    P = [p for p in [frozenset(m.accept), frozenset(non_acc)] if p]
    def grp_map(partition):
        m_map = {}
        for idx, grp in enumerate(partition):
            for s in grp:
                m_map[s] = idx
        return m_map
    changed = True
    while changed:
        changed = False
        new_P = []
        gm = grp_map(P)
        for grp in P:
            splits = defaultdict(set)
            for s in grp:
                sig = tuple(gm.get(m.transitions.get(s, {}).get(sym), -1)
                            for sym in sorted(m.alphabet))
                splits[sig].add(s)
            if len(splits) > 1:
                changed = True
            for sub in splits.values():
                new_P.append(frozenset(sub))
        P = new_P
    gm = grp_map(P)
    # store old transitions before we override them
    old_transitions = m.transitions 
    m.transitions = {}
    m.states = set(range(len(P))) #correct state types back to neat integers
    m.start  = gm[m.start]
    m.accept = {gm[s] for s in m.accept}
    for idx, grp in enumerate(P):
        rep = next(iter(grp)) 
        m.transitions[idx] = {}
        for sym in m.alphabet:
            nxt = old_transitions.get(rep, {}).get(sym)
            if nxt is not None:
                m.transitions[idx][sym] = gm[nxt]      
    return _wrap(m, (A.name + "_min") if isinstance(A, Automaton) else "min")

def regex_to_nfa(pattern: str) -> Automaton:
    return _wrap(NFA(pattern), f"re({pattern})")

def nfa_to_regex(A) -> str:
    return _state_elimination(DFA(_get_machine(A)))

def dfa_to_regex(A) -> str:
    m = _get_machine(A)
    if isinstance(m, NFA):
        raise RuntimeError("dfa_to_regex requires a DFA; use nfa_to_regex for NFAs")
    return _state_elimination(m)

def _state_elimination(d: DFA) -> str:
    # build the GNFA for state elimination
    SS, SA = "__SS__", "__SA__"
    gnfa = defaultdict(lambda: defaultdict(lambda: None))

    for s, trans in d.transitions.items():
        for sym, tgt in trans.items():
            prev = gnfa[s][tgt]
            gnfa[s][tgt] = sym if prev is None else f"({prev}|{sym})"

    gnfa[SS][d.start] = ""
    for acc in d.accept:
        p = gnfa[acc][SA]
        gnfa[acc][SA] = "" if p is None else f"({p}|)"

    interior  = list(d.states)  # must use .states to include states with no outgoing edges
    remaining = [SS] + interior + [SA]

    def re_union(a, b):
        if a is None: return b
        if b is None: return a
        if a == b:    return a
        return f"({a}|{b})"

    def re_concat(a, b):
        if a is None or b is None: return None
        if a == "": return b
        if b == "": return a
        def wrap(r):
            d = 0
            for c in r:
                if c == '(':   d += 1
                elif c == ')': d -= 1
                elif c == '|' and d == 0: return f"({r})"
            return r
        return wrap(a) + wrap(b)

    def re_star(a):
        if a is None or a == "": return ""
        if a.endswith('*'):       return a
        if len(a) == 1 or (a[0] == '(' and a[-1] == ')'): return f"{a}*"
        return f"({a})*"

    for elim in interior:
        loop   = gnfa[elim][elim]
        lstar  = re_star(loop) if loop is not None else None
        preds  = [p for p in remaining if p != elim and gnfa[p][elim] is not None]
        succs  = [s for s in remaining if s != elim and gnfa[elim][s] is not None]
        for pred in preds:
            for succ in succs:
                bridge = re_concat(re_concat(gnfa[pred][elim], lstar),
                                   gnfa[elim][succ]) if lstar is not None \
                         else re_concat(gnfa[pred][elim], gnfa[elim][succ])
                gnfa[pred][succ] = re_union(gnfa[pred][succ], bridge)
        remaining.remove(elim)
    result = gnfa[SS][SA]
    if result is None: return "(empty language)"

    #clean up unnecessary outer parentheses
    while result.startswith('(') and result.endswith(')'):
        d = 0
        early_close = False
        for i, c in enumerate(result):
            if c == '(':   d += 1
            elif c == ')': d -= 1
            if d == 0 and i < len(result) - 1:
                early_close = True; break
        if early_close: break
        result = result[1:-1]
    return result

def accepts(A, s: str) -> bool:
    d = _ensure_dfa(A)
    state = d.start
    for ch in s:
        state = d.transitions.get(state, {}).get(ch)
        if state is None:
            return False
    return state in d.accept

def trace(A, s: str) -> list:
    d     = _ensure_dfa(A)
    state = d.start
    steps = [("START", f"q{state}")]
    for ch in s:
        nxt = d.transitions.get(state, {}).get(ch)
        if nxt is None:
            steps.append((f"read '{ch}'", f"q{state} → DEAD (no transition)"))
            steps.append(("RESULT", "rejected"))
            return steps
        steps.append((f"read '{ch}'", f"q{state} → q{nxt}"))
        state = nxt
    accepted = state in d.accept
    steps.append(("RESULT", "accepted" if accepted else "rejected"))
    return steps

def equivalent(A, B):
    da = DFA(_get_machine(A))
    db = DFA(_get_machine(B))
    alpha = da.alphabet | db.alphabet
    da = _complete(da, alpha)
    db = _complete(db, alpha)
    #use symmetric difference dfa directly to find mismatches
    sym_diff = _product_dfa(da, db, alpha, "xor")
    if not sym_diff.accept:
        return True
    #bfs to find the shortest witness string
    start_id = sym_diff.start
    queue    = deque([(start_id, "")])
    visited  = {start_id}
    while queue:
        state, word = queue.popleft()
        if state in sym_diff.accept:
            return word
        for sym in sorted(alpha):
            nxt = sym_diff.transitions.get(state, {}).get(sym)
            if nxt is not None and nxt not in visited:
                visited.add(nxt)
                queue.append((nxt, word + sym))
    return True

def regex_equivalent(r1: str, r2: str) -> bool:
    return equivalent(_wrap(NFA(r1)), _wrap(NFA(r2))) is True

def validate(A) -> bool:
    errors = []
    name   = A.name if isinstance(A, Automaton) else "automaton"
    if isinstance(A, Automaton) and A._orig_states:
        state_set = set(A._orig_states)
        alpha_set = set(A._orig_alphabet)
        start     = A._orig_start
        final_set = set(A._orig_final)
        trans     = A._orig_transitions
        is_dfa    = (A.kind == "DFA")
    else:
        m = _get_machine(A)
        if isinstance(m, DFA):
            state_set = set(m.transitions.keys())
            alpha_set = m.alphabet
            start     = m.start
            final_set = m.accept
            trans     = m.transitions
            is_dfa    = True
        else:
            state_set = m.states
            alpha_set = m.alphabet
            start     = m.start
            final_set = m.accept
            trans     = m.transitions
            is_dfa    = False

    #basic checks
    if start not in state_set:
        errors.append(f"  Start state {start!r} is not in the states list")
    for f in final_set:
        if f not in state_set:
            errors.append(f"  Final state {f!r} is not in the states list")
    for src, sym_map in trans.items():
        if src not in state_set:
            errors.append(f"  Transition source {src!r} is not in the states list")
        for sym, tgts in sym_map.items():
            if sym != 'eps' and sym != 'ε' and sym not in alpha_set:
                errors.append(f"  Symbol {sym!r} at state {src!r} is not in the alphabet")
            if is_dfa and sym in ('eps', 'ε'):
                errors.append(f"  DFA cannot have epsilon transitions (state {src!r})")
            target_list = tgts if isinstance(tgts, (list, set)) else [tgts]
            if is_dfa and len(target_list) > 1:
                errors.append(f"  DFA has non-deterministic transition at ({src!r}, {sym!r})")
            for tgt in target_list:
                if tgt not in state_set:
                    errors.append(f"  Transition target {tgt!r} (from {src!r} on {sym!r}) "
                                  f"is not in the states list")
    if errors:
        print(f"[validate] '{name}' — {len(errors)} error(s):")
        for e in errors: print(e)
    else:
        print(f"[validate] '{name}' — all checks passed.")
    return len(errors) == 0

def subset(A, B) -> bool:
    return is_empty(difference(A, B))

def is_empty(A) -> bool:
    d = _ensure_dfa(A)
    visited  = {d.start}
    worklist = [d.start]
    while worklist:
        s = worklist.pop()
        if s in d.accept:
            return False
        for nxt in d.transitions.get(s, {}).values():
            if nxt not in visited:
                visited.add(nxt); worklist.append(nxt)
    return True

def is_finite(A) -> bool:
    d = _ensure_dfa(A)
    reach = _reachable_ids(d)
    rev = defaultdict(set)
    for s, tr in d.transitions.items():
        for t in tr.values():
            rev[t].add(s)
    can_reach = set(d.accept)
    wl = list(d.accept)
    while wl:
        s = wl.pop()
        for pred in rev[s]:
            if pred not in can_reach:
                can_reach.add(pred); wl.append(pred)
    useful = reach & can_reach
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {s: WHITE for s in useful}
    
    def has_cycle(s):
        color[s] = GRAY
        for t in d.transitions.get(s, {}).values():
            if t not in useful: continue
            if color[t] == GRAY:  return True
            if color[t] == WHITE and has_cycle(t): return True
        color[s] = BLACK
        return False
    for s in useful:
        if color[s] == WHITE and has_cycle(s):
            return False
    return True

def is_minimal(A) -> bool:
    m = _get_machine(A)
    if isinstance(m, NFA):
        raise RuntimeError("is_minimal requires a DFA; use is_minimal(determinize(M))")
    before = len(_reachable_ids(m))
    minimal_dfa = _get_machine(minimize(A)) 
    after  = len(minimal_dfa.states)  # State count is safer than transition count
    return before == after

def is_deterministic(A) -> bool:
    m = _get_machine(A)
    if isinstance(m, DFA): return True
    for sm in m.transitions.values():
        if 'ε' in sm: return False
        if any(len(tgts) > 1 for tgts in sm.values()): return False
    return True

def reachable(A) -> list:
    d = _ensure_dfa(A)
    return sorted(f"q{s}" for s in _reachable_ids(d))

def dead_states(A) -> list:
    d = _ensure_dfa(A)
    all_ids = set(d.states)  # ensures isolated states are caught
    rev = defaultdict(set)
    for s, tr in d.transitions.items():
        for t in tr.values():
            rev[t].add(s)
    can_reach = set(d.accept)
    wl = list(d.accept)
    while wl:
        s = wl.pop()
        for pred in rev[s]:
            if pred not in can_reach:
                can_reach.add(pred); wl.append(pred)
    return sorted(f"q{s}" for s in all_ids - can_reach)

# I/O formatting
def dsl_print(val) -> None:
    if isinstance(val, Automaton):
        table(val)
    elif isinstance(val, bool):
        print("true" if val else "false")
    elif isinstance(val, list) and val and isinstance(val[0], tuple):
        for event, detail in val:
            print(f"  {event:<25} {detail}")
    else:
        print(val)

def visualize(A, filename="automaton", fmt="png", view=True) -> None:
    m    = _get_machine(A)
    name = A.name if isinstance(A, Automaton) else "automaton"
    dot  = Digraph(graph_attr={"rankdir": "LR"})
    def add_node(node_id, label, is_accept, is_start):
        shape = "doublecircle" if is_accept else "circle"
        color = "lightgreen" if is_accept else ("lightyellow" if is_start else "lightblue")
        dot.node(node_id, label=label, shape=shape, style="filled", fillcolor=color)
    if isinstance(m, DFA):
        def ql(i): return "qDEAD" if i == -1 else f"q{i}"
        for idx in m.states:  # Ensures isolated states are drawn
            add_node(ql(idx), ql(idx), idx in m.accept, idx == m.start)
        dot.node("__s__", label="", shape="none", width="0")
        dot.edge("__s__", ql(m.start))
        edges = defaultdict(list)
        for idx, tr in m.transitions.items():
            for sym, tgt in tr.items():
                edges[(ql(idx), ql(tgt))].append(sym)
        for (src, dst), syms in edges.items():
            dot.edge(src, dst, label=", ".join(sorted(syms)))
    else:
        for s in sorted(m.states, key=str):
            add_node(str(s), str(s), s in m.accept, s == m.start)
        dot.node("__s__", label="", shape="none", width="0")
        dot.edge("__s__", str(m.start))
        edges = defaultdict(list)
        for s, sm in m.transitions.items():
            for sym, tgts in sm.items():
                for t in (tgts if isinstance(tgts, (set, list)) else [tgts]):
                    edges[(str(s), str(t))].append(sym)
        for (src, dst), syms in edges.items():
            dot.edge(src, dst, label=", ".join(sorted(syms)))
    dot.render(filename, format=fmt, view=view, cleanup=True)
    print(f"[visualize] Saved → {filename}.{fmt}")

def table(A) -> None:
    m    = _get_machine(A)
    name = A.name if isinstance(A, Automaton) else "automaton"
    if isinstance(m, DFA):
        states = sorted(m.states, key=str) # Display all states
        alpha  = sorted(m.alphabet)
        accept = m.accept
        start  = m.start
        lbl    = lambda s: f"q{s}"
        cell   = lambda s, sym: (f"q{m.transitions[s][sym]}"
                                 if sym in m.transitions.get(s, {}) else "-")
    else:
        states = sorted(m.states, key=str)
        alpha  = sorted(m.alphabet)
        if any('ε' in sm for sm in m.transitions.values()):
            alpha += ['ε']
        accept = m.accept
        start  = m.start
        lbl    = lambda s: str(s)
        def cell(s, sym):
            t = m.transitions.get(s, {}).get(sym, set())
            return "{" + ",".join(str(x) for x in sorted(t, key=str)) + "}" if t else "-"      
    cw = max(8, max((len(a) for a in alpha), default=4) + 2)
    sw = max(10, max((len(lbl(s)) for s in states), default=4) + 4)
    print(f"\n  {m.__class__.__name__}: {name}")
    print("  " + "=" * (sw + cw * len(alpha)))
    print(f"  {'State':<{sw}}" + "".join(f"{a:^{cw}}" for a in alpha))
    print("  " + "-" * (sw + cw * len(alpha)))
    for s in states:
        mark = ("→" if s == start else " ") + ("*" if s in accept else " ")
        row  = f"  {mark}{lbl(s):<{sw-2}}"
        for sym in alpha:
            row += f"{cell(s, sym):^{cw}}"
        print(row)
    print()

def stats(A) -> None:
    m    = _get_machine(A)
    name = A.name if isinstance(A, Automaton) else "automaton"
    if isinstance(m, DFA):
        n_st = len(m.states)
        n_ac = len(m.accept)
        n_tr = sum(len(t) for t in m.transitions.values())
        al   = m.alphabet
    else:
        n_st = len(m.states)
        n_ac = len(m.accept)
        n_tr = sum(len(t) for t in m.transitions.values())
        al   = m.alphabet
    print(f"\n[stats] {m.__class__.__name__}: {name}")
    print(f"  States        : {n_st}")
    print(f"  Alphabet      : {len(al)}  ({', '.join(sorted(al))})")
    print(f"  Accept states : {n_ac}")
    print(f"  Transitions   : {n_tr}")
    print(f"  Deterministic : {is_deterministic(A)}")
    print(f"  Empty language: {is_empty(A)}")
    print()

def export(A, filepath: str) -> None:
    m    = _get_machine(A)
    name = A.name if isinstance(A, Automaton) else "automaton"
    ext  = os.path.splitext(filepath)[1].lower()
    if ext == ".json":
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(_to_dict(m, name), f, indent=2, ensure_ascii=False)
        print(f"[export] JSON → {filepath}")
    elif ext == ".dot":
        with open(filepath, "w") as f:
            f.write(_to_dot(m, name))
        print(f"[export] DOT → {filepath}")
    elif ext == ".png":
        dot_path = filepath[:-4] + ".dot"
        with open(dot_path, "w") as f:
            f.write(_to_dot(m, name))
        try:
            subprocess.run(["dot", "-Tpng", dot_path, "-o", filepath], check=True)
            print(f"[export] PNG → {filepath}")
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(f"[export] Graphviz CLI not found — DOT saved → {dot_path}")
    else:
        raise RuntimeError(f"export: unknown extension '{ext}'. Use .json, .dot, or .png")

def import_automaton(filepath: str) -> Automaton:
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"import: file not found: {filepath!r}")
    with open(filepath, "r", encoding="utf-8") as f:
        d = json.load(f)
    kind   = d["type"].upper()
    name   = d.get("name", "imported")
    states = d["states"]
    alpha  = d["alphabet"]
    start  = d["start"]
    final  = d["accept"]
    raw_t  = d["transitions"]
    norm = {}
    for s, sm in raw_t.items():
        norm[s] = {}
        for sym, tgts in sm.items():
            norm[s][sym] = set(tgts) if isinstance(tgts, list) else {tgts}
    if kind == "NFA":
        m = NFA(states=set(states), alphabet=set(alpha),
                transitions=norm, start=start, accept=set(final))
        return _wrap(m, name)
    else:
        dfa_t = {s: {sym: next(iter(tgts)) for sym, tgts in sm.items()}
                 for s, sm in norm.items()}
        m = DFA(states=set(states), alphabet=set(alpha),
                transitions=dfa_t, start=start, accept=set(final))
        return _wrap(m, name)

def str_reverse(s: str) -> str:
    return s[::-1]

def str_concat(a: str, b: str) -> str:
    return a + b

def chars(s: str) -> list:
    return list(s)

def random_str(length: int, alphabet: str) -> str:
    if not alphabet:
        raise ValueError("random_str: alphabet cannot be empty")
    return "".join(random.choice(alphabet) for _ in range(length))

def _append(lst: list, val) -> None:
    lst.append(val)

def _remove(lst: list, idx: int) -> None:
    if idx < 0 or idx >= len(lst):
        raise IndexError(
            f"remove: index {idx} out of range for list of length {len(lst)}"
        )
    del lst[idx]

def _to_dict(m, name: str) -> dict:
    if isinstance(m, DFA):
        return {
            "name":        name,
            "type":        "dfa",
            "states":      [str(s) for s in sorted(m.states, key=str)],
            "alphabet":    sorted(m.alphabet),
            "start":       str(m.start),
            "accept":      [str(s) for s in sorted(m.accept, key=str)],
            "transitions": {
                str(s): {sym: [str(t)] for sym, t in tr.items()}
                for s, tr in m.transitions.items()
            }
        }
    return {
        "name":        name,
        "type":        "nfa",
        "states":      [str(s) for s in sorted(m.states, key=str)],
        "alphabet":    sorted(m.alphabet),
        "start":       str(m.start),
        "accept":      [str(s) for s in sorted(m.accept, key=str)],
        "transitions": {
            str(s): {sym: [str(t) for t in sorted(tgts, key=str)]
                     for sym, tgts in sm.items()}
            for s, sm in m.transitions.items()
        }
    }

def _to_dot(m, name: str) -> str:
    lines = [f'digraph "{name}" {{', '  rankdir=LR;']
    if isinstance(m, DFA):
        for s in m.states:
            shape = "doublecircle" if s in m.accept else "circle"
            lines.append(f'  "{s}" [shape={shape}];')
        lines += ['  "__s__" [shape=none label=""];',
                  f'  "__s__" -> "{m.start}";']
        merged = defaultdict(list)
        for s, tr in m.transitions.items():
            for sym, t in tr.items():
                merged[(f"{s}", f"{t}")].append(sym)
        for (src, dst), syms in merged.items():
            lines.append(f'  "{src}" -> "{dst}" [label="{", ".join(sorted(syms))}"];')
    else:
        for s in m.states:
            shape = "doublecircle" if s in m.accept else "circle"
            lines.append(f'  "{s}" [shape={shape}];')
        lines += ['  "__s__" [shape=none label=""];',
                  f'  "__s__" -> "{m.start}";']
        merged = defaultdict(list)
        for s, sm in m.transitions.items():
            for sym, tgts in sm.items():
                for t in tgts:
                    merged[(str(s), str(t))].append(sym)
        for (src, dst), syms in merged.items():
            lines.append(f'  "{src}" -> "{dst}" [label="{", ".join(sorted(syms))}"];')
    lines.append("}")
    return "\n".join(lines)
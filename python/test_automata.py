from runtime import regex_to_nfa, animate_trace
re_nfa = regex_to_nfa("(a|a*)")
animate_trace(re_nfa, "aaaba")
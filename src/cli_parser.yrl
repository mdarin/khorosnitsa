Header 
"%% Copyright (C)"
"%% @private"
"%% @Author John".

Nonterminals list expr exprs.

Terminals '{' '}' '(' ')'.

Rootsymbol list.

list -> exprs :
    % io:format("~p~n", ['$1']),
    case lists:foldl(fun
            (push, Acc) -> [push | Acc];
            (pop, [_ | Acc]) -> Acc; 
            (_, Acc) -> Acc
        end, [], '$1') of 
        [] -> completed;
        _ -> continue
    end.
    
exprs -> expr exprs : ['$1' | '$2']. 
exprs -> '$empty' : [nil].

expr -> '(' : push.
expr -> ')' : pop.
expr -> '{' : push.
expr -> '}' : pop.

Erlang code.

% value_of(Token) -> 
%     element(3, Token).

% line_of(Token) -> 
%     element(2, Token).    

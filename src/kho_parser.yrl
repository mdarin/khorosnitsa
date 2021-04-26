Header 
"%% Copyright (C)"
"%% @private"
"%% @Author John".

%% Erlang grammar https://github.com/erlang/otp/blob/master/lib/stdlib/src/erl_parse.yrl

Nonterminals 
list expr number unariminus exprs assign 
statement statements condition
while_clause if_clause else_clause return. 

Terminals 
'(' ')' '+' '*' '-' '/' '=' '^' ';' '{' '}' 
%'==' '/=' '>=' '=<'  '<' '>'
integer float const builtin variable
'IF' 'ELSE' 'WHILE' 'PRINT' 'REM' 'DIV'. 
% register.

Right 100 '='.
Left 300 '+' '-'.
Left 400 '*' '/'.
Unary 500 unariminus.
Right 600 '^'.

Rootsymbol list.


%% Grammar rules

% утверждение = выражение(expr) 
% | if_clause 
% | if_else_clauese 
% | while_clause 
% | print_clause 
% | group_clause

list -> exprs :
    'Elixir.Khorosnitsa.Mem':unshift(halt),
    valid_grammar.
list -> '$empty' : 
    nil.

% 


statement -> 'PRINT' expr : '$1'.
% statement -> '{' statements '}' : '$1'.
statement -> '{' list '}' : '$1'.
statement -> while_clause condition statement return.
statement -> if_clause condition statement return.
statement -> if_clause condition statement return else_clause statement return.

statements -> statement statements : ['$1' | '$2'].
statements -> '$empty'.

while_clause -> 'WHILE'. % по идее тут надо зарезервировать две позиции в стеке?
if_clause -> 'IF'. % тут по идее надо резервировать ячейки, три штуки
else_clause -> 'ELSE'.

condition -> '(' expr ')'. 

return -> '$empty'. % это завершение вложенной секции по идее

exprs -> expr :
    '$1'.
exprs -> expr ';' exprs:
    ['$1' | '$3'].

expr -> assign : nil.
expr -> expr '+' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(add). 
expr -> expr '*' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(mul).
% /	Division of numerator by denominator
expr -> expr '/' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(dond).
% rem Remainder of dividing the first number by the second
expr -> expr 'REM' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(remi).
% div The div component will perform the division and return the integer component.
expr -> expr 'DIV' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(divi).
expr -> expr '-' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(sub).
expr -> '(' expr ')' : nil.
expr -> expr '^' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(pow).
expr -> builtin '(' expr ')' : 
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, bltin, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(bltin).
%expr -> variable '=' expr : 'Elixir.Khorosnitsa.Mem':unshift({mov, '$1'}).
expr -> variable : 
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, var, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(var).
expr -> const : 
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, const, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(const).
expr -> unariminus : nil.
expr -> number : nil. 
expr -> statement.

unariminus -> '-' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(neg). % negate

assign -> variable '=' expr : 
    % 'Elixir.Khorosnitsa.Mem':unshift({mov, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(mov).

number -> integer : 
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')).
number -> float : 
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')).


Erlang code.

value_of(Token) -> 
    element(3, Token).

% line_of(Token) -> 
%     element(2, Token).    
Header 
"%% Copyright (C)"
"%% @private"
"%% @Author John".

%% Erlang grammar https://github.com/erlang/otp/blob/master/lib/stdlib/src/erl_parse.yrl

Nonterminals 
list expr number unariminus exprs assign 
statement statements condition
clause clauses
while_clause if_clause else_clause done. 

Terminals 
'(' ')' '+' '*' '-' '/' '=' '^' ';' '{' '}' 
'==' '/=' '>=' '=<' '<' '>'
integer float const builtin variable 'SEP'
'IF' 'ELSE' 'WHILE' 'PRINT' 'REM' 'DIV'. 
% register.

Right 100 '='.
Nonassoc 200 '=='.% '=/='.
Left 300 '+' '-'.
Left 400 '*' '/'.
Unary 500 unariminus.
Right 600 '^'.

Rootsymbol list.


%% Grammar rules

%% Примерная грамматика
% модуль или документ = пункт(clause) | EMPTY.
% clause = выражение(expr) | утверждение(statemetn).
% expr = NUMBER
% | VARIABLE
% | !expr
% | -expr
% | expr < exps
% | expr > expr
% | expr >= expr
% | expr =< expr
% | expr == expr
% | expr != expr
% | expr && expr
% | expr || expr
% утверждение(statemetn) = if_clause 
% | if_else_clauese 
% | while_clause 
% | print_clause 
% | read_clause
% | group_clause

% list -> exprs :
list -> clauses :
    io:format("S1 -> ~p~n", ['$1']),
    'Elixir.Khorosnitsa.Mem':unshift(halt),
    valid_grammar.
% list -> '$empty' : 
%     nil.

clauses -> clause clauses :
    ['$1' | '$2'].
clauses -> '$empty' :
    nil.

clause -> expr : '$1'.
clause -> statement : '$1'.

statement -> 'PRINT' expr : %'$1'.
    % io:format("~p  ~p~n", ['$1', '$2']).
    'Elixir.Khorosnitsa.Mem':unshift(prn).

statement -> while_clause condition statement done.

%% Вроде как хорошая идея
% Обычно оператор «IF» реализуется с использованием условного перехода, 
% который выполняется, если условие ложно. Рассмотрим, вместо этого, 
% подпрограмму, содержащую весь код оператора «IF». 
% Точкой входа будет вызов такой подпрограммы. 
% Первым выходом станет условный выход из неё, выполняемый, если условие ложно. 
% Вторым выходом будет безусловный возврат управления.
statement -> if_clause condition statement done : 
    io:format(" ** IF ~p ~p ~p ~p~n", ['$1', '$2', '$3', '$4']),
    ['$1', '$2', '$3'].
% Получается следующая схема: 
% if_clause - это вызов подпрограммы содержащей весь код оператора IF.
% Тело оператора IF, непосредственно код, он содержится statement.
% Первый выход - условынй, он содержится в condition.
% Второй выход - безусловный возврат управления, он содержится в done(exit, ret, как будет)


statement -> if_clause condition statement done else_clause statement done.
% statement -> '{' statements '}' : '$1'.
% statement -> '{' list '}' : '$1'.
statement -> '{' clauses '}' : 
    '$1'.

% statements -> statement statements : ['$1' | '$2'].
% statements -> '$empty'.

% Когда встречается ключевое слово while, генерируется операция whilecode, 
% и его позиция в машине возвращается как значение порождающего правила
while_clause -> 'WHILE' : % по идее тут надо зарезервировать две позиции в стеке? 
    % nested
    'Elixir.Khorosnitsa.Mem':nested(),
    % поместим в очередь команд метку начала циклической конструкции
    % Pos = 
    'Elixir.Khorosnitsa.Mem':unshift(loop_while), 
    % поместим также и метку начала условного выражения определяющего цикл(условие)
    % 'Elixir.Khorosnitsa.Mem':unshift(cond_expr),
    % 'Elixir.Khorosnitsa.Mem':put("position", Pos).
    ok.

if_clause -> 'IF': '$1', % тут по идее надо резервировать ячейки, три штуки
    'Elixir.Khorosnitsa.Mem':nested(),
    % поместим в очередь команд метку начала конструкции ветвления
    'Elixir.Khorosnitsa.Mem':unshift(if_then), 
    ok.

else_clause -> 'ELSE':
    'Elixir.Khorosnitsa.Mem':nested(),
    % поместим в очередь команд метку альтернативы конструкции ветвления
    'Elixir.Khorosnitsa.Mem':unshift(else_then), 
    ok.


condition -> '(' expr ')':
    % после разбора условия цикла, поместим в очередь команд метку начала тела цикла
    %'Elixir.Khorosnitsa.Mem':unshift(done),
    'Elixir.Khorosnitsa.Mem':unshift(cond_expr).
    % 'Elixir.Khorosnitsa.Mem':unshift(body).


done -> '$empty':  % это завершение вложенной секции по идее
    'Elixir.Khorosnitsa.Mem':unshift(done),
    % embed nested commands
    'Elixir.Khorosnitsa.Mem':embed_nested(),
    WhilePos = 'Elixir.Khorosnitsa.Mem':get("position"),
    % свернуть код стэйтмента в список и сделать его элементов стэка
    % -1 нужно чтобы захватить в сворачиваемый кусок команду while_loop
    % 'Elixir.Khorosnitsa.Mem':roll_up(WhilePos-1).
    ok.


exprs -> expr :
    '$1'.
exprs -> expr 'SEP' exprs:
    ['$1' | '$3'].

expr -> assign : 
    nil.
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
%% https://www.mathsisfun.com/equal-less-greater.html
% lt (less than)
expr -> expr '<' expr :
    'Elixir.Khorosnitsa.Mem':unshift(lt).
% gt (greater than)
expr -> expr '>' expr :
    'Elixir.Khorosnitsa.Mem':unshift(gt).
% ge (greater than or equal to)
expr -> expr '>=' expr :
    'Elixir.Khorosnitsa.Mem':unshift(ge).
% le (less than or equal to)
expr -> expr '=<' expr :
    'Elixir.Khorosnitsa.Mem':unshift(le).
% eq (equals)
expr -> expr '==' expr :
    'Elixir.Khorosnitsa.Mem':unshift(eq).
% ne (not equal to)
expr -> expr '/=' expr :
    'Elixir.Khorosnitsa.Mem':unshift(ne).
expr -> builtin '(' expr ')' : 
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, bltin, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(bif). % 'BIF' или bif
%expr -> variable '=' expr : 'Elixir.Khorosnitsa.Mem':unshift({mov, '$1'}).
expr -> variable : 
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, var, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(var),
    '$1'. % <--- это очень важно, оставлять то что требеется на вершине стека
expr -> const : 
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, const, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(const).
expr -> unariminus : nil.
expr -> number : nil. 
% expr -> statement.

unariminus -> '-' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(neg). % negate

assign -> variable '=' expr : 
    % 'Elixir.Khorosnitsa.Mem':unshift({mov, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(mov).

number -> integer : 
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')), 
    '$1'.
number -> float : 
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')).


Erlang code.

value_of(Token) -> 
    element(3, Token).

% line_of(Token) -> 
%     element(2, Token).    
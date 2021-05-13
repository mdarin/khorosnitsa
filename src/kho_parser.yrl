Header 
"%% Copyright (C)"
"%% @private"
"%% @Author John".

%% Erlang grammar https://github.com/erlang/otp/blob/master/lib/stdlib/src/erl_parse.yrl
%% Go grammar https://golang.org/ref/spec

%%% Про области видимости
% Они работают по принципу пирамиды
% Чем выше тем больше видно, но тем и меньше площадь на которой переманная действует
% Глобальная область меет самую большую площадь но и неё ничего кроме голабальных переменных не видно
% Лакальная же область например находящаяся на самой вершине пирамиды видит все переменные вплоть до 
% глобальных однако действуют эти переменные только лишь в пределах это локальной области видимости(читай площади)

Nonterminals 
list expr number unariminus negation bnegation assign 
statement condition variable
clause clauses arguments
while_clause if_clause else_clause func_clause 
delimiter func_decl end_decl %signature  %argument
exit done. 

Terminals 
'(' ')' '+' '*' '-' '/' '=' '^'  
'==' '/=' '>=' '=<' '<' '>'
'AND' 'OR' 'XOR' 'NOT' 
'BAND' 'BOR' 'BXOR' 'BNOT' 'BSL' 'BSR'
'{' '}' ',' ';' 'LF'
integer float const builtin 'IDENTIFIER'
'IF' 'ELSE' 'WHILE' 'PRINT' 'REM' 'DIV' 'FUNC'. 

Right 100 '='.
Nonassoc 200 '==' '/='.
Left 300 '+' '-' 'OR' 'XOR' 'BOR' 'BXOR'.
Left 400 '*' '/' 'DIV' 'REM' 'AND' 'BAND' 'BSL' 'BSR'.
Unary 500 bnegation.
Unary 500 negation.
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

list -> clauses :
    'Elixir.Khorosnitsa.Mem':unshift(halt),
    '$1'.

clauses -> clause delimiter clauses :
    ['$1' | '$3'].
clauses -> '$empty' :
    [nil].

clause -> expr : 
    '$1'.
clause -> statement : 
    '$1'.


% на уровне clause заменено
% exprs -> expr :
%     '$1'.
% exprs -> expr ';' exprs:
%     ['$1' | '$3'].


statement -> 'PRINT' expr :
    'Elixir.Khorosnitsa.Mem':unshift(prn),
    {<<"print">>, '$2'}.
statement -> func_clause func_decl end_decl statement exit :
    {'$1', '$2', '$4'}.
statement -> while_clause condition statement done :
    {'$1', '$2', '$3'}.

%% Вроде как хорошая идея
% Обычно оператор «IF» реализуется с использованием условного перехода, 
% который выполняется, если условие ложно. Рассмотрим, вместо этого, 
% подпрограмму, содержащую весь код оператора «IF». 
% Точкой входа будет вызов такой подпрограммы. 
% Первым выходом станет условный выход из неё, выполняемый, если условие ложно. 
% Вторым выходом будет безусловный возврат управления.
statement -> if_clause condition statement done :
    {'$1', '$2', '$3'}.
% Получается следующая схема: 
% if_clause - это вызов подпрограммы содержащей весь код оператора IF.
% Тело оператора IF, непосредственно код, он содержится statement.
% Первый выход - условынй, он содержится в condition.
% Второй выход - безусловный возврат управления, он содержится в done(exit, ret, как будет)

statement -> if_clause condition statement done else_clause statement done :
    {'$1', '$2', '$3', '$5', '$6'}.
% statement -> '{' statements '}' : '$1'.
% statement -> '{' list '}' : '$1'.
statement -> '{' delimiter clauses delimiter '}' :
    {<<"begin">>, '$3', <<"end">>}.
% statement -> '{' clauses 'RETURN' '}' :
%     ok.
% statement -> '{' clauses 'RETURN' expr '}'.
% statements -> statement statements : ['$1' | '$2'].
% statements -> '$empty'.

% Когда встречается ключевое слово while, генерируется операция whilecode, 
% и его позиция в машине возвращается как значение порождающего правила
while_clause -> 'WHILE' : % по идее тут надо зарезервировать две позиции в стеке? 
    % nested code
    'Elixir.Khorosnitsa.Mem':nested(),
    % поместим в очередь команд метку начала циклической конструкции
    'Elixir.Khorosnitsa.Mem':unshift(loop_while),
    <<"while">>.

if_clause -> 'IF': % тут по идее надо резервировать ячейки, три штуки
    'Elixir.Khorosnitsa.Mem':nested(),
    % поместим в очередь команд метку начала конструкции ветвления
    'Elixir.Khorosnitsa.Mem':unshift(if_then),
    <<"if">>.

else_clause -> 'ELSE':
    'Elixir.Khorosnitsa.Mem':nested(),
    % поместим в очередь команд метку альтернативы конструкции ветвления
    'Elixir.Khorosnitsa.Mem':unshift(else_then),
    <<"else">>.

condition -> '(' expr ')':
    % после разбора условия цикла, поместим в очередь команд метку начала тела цикла
    'Elixir.Khorosnitsa.Mem':unshift(cond_expr),
    {<<"(">>, '$2', <<")">>}.

func_clause -> 'FUNC' :
    'Elixir.Khorosnitsa.Mem':nested(),
    % поместим в очередь команд метку подпрограммы 
    'Elixir.Khorosnitsa.Mem':unshift(routine),
    <<"func">>.

func_decl -> 'IDENTIFIER' '(' arguments ')':
    % Arity — количество аргументов, принимаемых функцией(арность).
    % И её надо подчитать желательно в момент парсинга
    % Исходрое значение 0 - у функции нет аргументов
    % 'Elixir.Khorosnitsa.Mem':put(":Arity", 0),
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    {value_of('$1'), <<"(">>, '$3', <<")">>}.

end_decl -> '$empty' : 
    'Elixir.Khorosnitsa.Mem':unshift(body).


arguments -> expr delimiter arguments:
    % подсчитать количество аргументов функции
    % Arity = 'Elixir.Khorosnitsa.Mem':get(":Arity"),
    % 'Elixir.Khorosnitsa.Mem':put(":Arity", Arity + 1).
    ['$1' | '$3'].
arguments -> '$empty':
    [nil].

% разделители сейчас общие, но их конечно надо разнести
% данный пример хорошо иллюстрирует работу правил
delimiter -> ','.
delimiter -> ';'.
delimiter -> 'LF'.
delimiter -> '$empty'.


done -> '$empty':  % это завершение вложенной секции по идее
    'Elixir.Khorosnitsa.Mem':unshift(done),
    % embed nested commands
    'Elixir.Khorosnitsa.Mem':embed_nested().

exit -> '$empty' :
    'Elixir.Khorosnitsa.Mem':unshift(done),
    % embed nested commands
    'Elixir.Khorosnitsa.Mem':embed_nested(),
    % place fucnction code into table 
    'Elixir.Khorosnitsa.Mem':place_function().


expr -> assign :
    %io:format("<E->ASSIGN>~n").
    '$1'.

expr -> expr '+' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(add),
    {'$1', <<"+">>, '$3'}. 
expr -> expr '*' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(mul),
    {'$1', <<"*">>, '$3'}. 
% /	Division of numerator by denominator
expr -> expr '/' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(dond),
    {'$1', <<"/">>, '$3'}. 
% rem Remainder of dividing the first number by the second
expr -> expr 'REM' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(remi),
    {'$1', <<"rem">>, '$3'}. 
% div The div component will perform the division and return the integer component.
expr -> expr 'DIV' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(divi),
    {'$1', <<"div">>, '$3'}. 
expr -> expr '-' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(sub),
    {'$1', <<"-">>, '$3'}. 
expr -> expr '^' expr : 
    'Elixir.Khorosnitsa.Mem':unshift(pow),
    {'$1', <<"^">>, '$3'}. 

expr -> expr 'BAND' expr : % binary conjunction
    'Elixir.Khorosnitsa.Mem':unshift(bconj),
    {'$1', <<"band">>, '$3'}. 
% TODO bitwise
%TODO expr OR exor disjunction
expr -> expr 'BSR' expr : % bit shift right
    'Elixir.Khorosnitsa.Mem':unshift(shr),
    {'$1', <<"bsr">>, '$3'}. 
expr -> expr 'BSL' expr : % bit shift left shl
    'Elixir.Khorosnitsa.Mem':unshift(shl),
    {'$1', <<"bsl">>, '$3'}. 

%TODO expr OR exor disjunction

% expr -> expr 'AND' expr : % logical conjunction
%     'Elixir.Khorosnitsa.Mem':unshift(conj).
% TODO logical

expr -> '(' expr ')' :
    {<<"(">>, '$2', <<")">>}.
%% https://www.mathsisfun.com/equal-less-greater.html
% lt (less than)
expr -> expr '<' expr :
    'Elixir.Khorosnitsa.Mem':unshift(lt),
    {'$1', <<"<">>, '$3'}. 
% gt (greater than)
expr -> expr '>' expr :
    'Elixir.Khorosnitsa.Mem':unshift(gt),
    {'$1', <<">">>, '$3'}. 
% ge (greater than or equal to)
expr -> expr '>=' expr :
    'Elixir.Khorosnitsa.Mem':unshift(ge),
    {'$1', <<">=">>, '$3'}. 
% le (less than or equal to)
expr -> expr '=<' expr :
    'Elixir.Khorosnitsa.Mem':unshift(le),
    {'$1', <<"=<">>, '$3'}. 
% eq (equals)
expr -> expr '==' expr :
    'Elixir.Khorosnitsa.Mem':unshift(eq),
    {'$1', <<"==">>, '$3'}. 
% ne (not equal to)
expr -> expr '/=' expr :
    'Elixir.Khorosnitsa.Mem':unshift(ne),
    {'$1', <<"/=">>, '$3'}. 
expr -> builtin '(' expr ')' : % 'BIF' или bif
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, bltin, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(bif),
    {'$1', <<"(">>, '$3', <<")">>}. 

expr -> func_decl :
    'Elixir.Khorosnitsa.Mem':unshift(call),
    '$1'. 
%expr -> variable '=' expr : 'Elixir.Khorosnitsa.Mem':unshift({mov, '$1'}).
expr -> variable : 
% expr -> 'IDENTIFIER':
    % io:format("<VAR>~n"),
    % ---- старое'Elixir.Khorosnitsa.Mem':unshift({eval, var, value_of('$1')}).
    % 'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(var),
    '$1'.
expr -> const : 
    % 'Elixir.Khorosnitsa.Mem':unshift({eval, const, value_of('$1')}).
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(const),
    value_of('$1').
expr -> unariminus :
    '$1'.
expr -> negation :
    '$1'.
expr -> bnegation :
    '$1'.
expr -> number :
    '$1'. 
% expr -> statement.

variable -> 'IDENTIFIER' :
    % io:format("<IDEN> ~p~n", [value_of('$1')]),
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    value_of('$1').

unariminus -> '-' expr : % negate 
    'Elixir.Khorosnitsa.Mem':unshift(neg),
    {<<"-">>, '$2'}.

negation -> 'NOT' expr : % invertion
    'Elixir.Khorosnitsa.Mem':unshift(inv),
    {<<"not">>, '$2'}.

bnegation -> 'BNOT' expr : % binary invertion
    'Elixir.Khorosnitsa.Mem':unshift(binv),
    {<<"bnot">>, '$2'}.

%%% TODO
%% d = e = g 
%% a = b = c = 1 # а вот так нельзя!
% assign -> 'IDENTIFIER' '=' expr : 
assign -> variable '=' expr : 
    % io:format("<ASSIGN> ~p~n", ['$3']),
    % ----- старое 'Elixir.Khorosnitsa.Mem':unshift({mov, value_of('$1')}).
    % 'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    'Elixir.Khorosnitsa.Mem':unshift(mov),
    {'$1', <<"=">>, '$3'}.

number -> integer : 
    % io:format("<NUM> ~p~n", ['$1']),
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')), 
    value_of('$1').
number -> float : 
    'Elixir.Khorosnitsa.Mem':unshift(value_of('$1')),
    value_of('$1').

Erlang code.

value_of(Token) -> 
    element(3, Token).

% line_of(Token) -> 
%     element(2, Token).    
Definitions.

% ручной вызов "PI" |> String.to_charlist |> :cli_lexer.string

% вызов модулей эликсира из эрланга можно делать так 'Elixr.<module>:<fucntion>(Args)
% или попробовать через apply(...) тоже модуль надо писать через Elixir.<module>
% 'Elixir.InterCli.Mem':load(a, 1),


% Erlang - Operators
% https://www.tutorialspoint.com/erlang/erlang_operators.htm

% книга лежитв загрузках stack_computers_book_text.pdf

%R     = [a-z]
WHITESPACE = [\s\t\v]
D = [0-9]
SYMBOL = [a-zA-Z][a-zA-Z_0-9]*
SEPARATOR = [\n;]

Rules.


% Keywords

while :
    {token, {'WHILE', TokenLine, TokenChars}}.

if :
    {token, {'IF', TokenLine, TokenChars}}.

else :
    {token, {'ELSE', TokenLine, TokenChars}}.

print :
    {token, {'PRINT', TokenLine, TokenChars}}.

read :
    {token, {'READ', TokenLine, TokenChars}}.

func :
    {token, {'FUNC', TokenLine, TokenChars}}.

return :
    {token, {'RETURN', TokenLine, TokenChars}}.

% Logical Operators

or :
    {token, {'OR', TokenLine, TokenChars}}.

and :	
    {token, {'AND', TokenLine, TokenChars}}.

not	:
    {token, {'NOT', TokenLine, TokenChars}}.

xor :
    {token, {'XOR', TokenLine, TokenChars}}.


% Bitwise Operators
	
band :
    {token, {'BAND', TokenLine, TokenChars}}.

bor :
    {token, {'BOR', TokenLine, TokenChars}}.

bxor :
    {token, {'BXOR', TokenLine, TokenChars}}.

bnot :
    {token, {'BNOT', TokenLine, TokenChars}}.

% http://erlang.org/pipermail/erlang-questions/2003-June/009193.html
% bsl - bit shift left
% bsr - bit shift right
bsl :
    {token, {'BSL', TokenLine, TokenChars}}.

bsr :
    {token, {'BSR', TokenLine, TokenChars}}.

% Line comments

([#].+?) :
    skip_token.

% Relational Operators

[=][=] :
    {token, {'==',  TokenLine}}.

[/][=] :
    {token, {'/=',  TokenLine}}.

[<]	:
    {token, {'<',  TokenLine}}.

[>]	:
    {token, {'>',  TokenLine}}.

[=][<] :
    {token, {'=<',  TokenLine}}.

[>][=] :
    {token, {'>=',  TokenLine}}.

[=] : 
    {token, {'=',  TokenLine}}.

% Arithmetic Operators

\^ :
    {token, {'^',  TokenLine}}.

[+] :
    {token, {'+',  TokenLine}}.

[*] :
    {token, {'*',  TokenLine}}.

[/] :
    {token, {'/',  TokenLine}}.

rem :
    {token, {'REM',  TokenLine}}.

div :
    {token, {'DIV',  TokenLine}}.

[-] :
    {token, {'-',  TokenLine}}.


% Ohter

[(] :
    {token, {'(',  TokenLine}}.

[)] :
    {token, {')',  TokenLine}}.

\{ :
    {token, {'{',  TokenLine}}.

\} :
    {token, {'}',  TokenLine}}.

[,] :
    {token, {',',  TokenLine}}.

[;] :
    {token, {';',  TokenLine}}.

[\n]+ :
    skip_token. % lf {end_token, {'$end', TokenLine}}.

[\r]+ :
    skip_token. % cr {end_token, {'$end', TokenLine}}.

(\r\n)+ :
    skip_token.  % crlf {end_token, {'$end', TokenLine}}.

{WHITESPACE}+ :
    skip_token.

% Numbers

{D}+ : 
    {token,{integer,TokenLine,list_to_integer(TokenChars)}}.

{D}+\.{D}+((E|e)(\+|\-)?{D}+)? : 
    {token,{float,TokenLine,list_to_float(TokenChars)}}.

% Identifiers

{SYMBOL} : 
    IsConst = 'Elixir.Khorosnitsa.Mem':is_constant(TokenChars),
    IsBuiltin = 'Elixir.Khorosnitsa.Mem':is_builtin(TokenChars),

    % io:format("is const ~p~n", [IsConst]),
    % io:format("is builtin ~p~n", [IsBuiltin]),

    if 
        % is constant?
         IsConst== true -> 
            {token, {const, TokenLine, TokenChars}};
        % is built in func?
         IsBuiltin== true -> 
            {token, {builtin, TokenLine, TokenChars}};
        % if neither constant and non built in function then indentifier
        true -> 
            % {token, {variable, TokenLine, TokenChars}}
            {token, {'IDENTIFIER', TokenLine, TokenChars}}
    end.

Erlang code.

%%%%
%% Converts string (list) to number ( interger or float )
%%%%
%list_to_number(L) when is_list(L) ->
%    Float = (catch erlang:list_to_float(L)),
%    Int = (catch erlang:list_to_integer(L)),
%    case is_number(Float) of
%        true ->
%            {ok, Float};
%        false ->
%            case is_number(Int) of
%                true ->
%                    {ok, Int};
%                false ->
%                    {error, 'not_a_number'}
%            end
%    end.

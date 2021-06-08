Definitions.

LITERAL = [^{}()\r\n]

WHITESPACE = [\s\t\v]

Rules.

{WHITESPACE}+ :
    skip_token.

[\n]+ :
    % {token, {'LF', TokenLine}}. % lf {end_token, {'$end', TokenLine}}.
    skip_token.

[\r]+ :
    % {token, {'CR', TokenLine}}. % cr {end_token, {'$end', TokenLine}}.
    skip_token.

(\r\n)+ :
    % {token, {'CRLF', TokenLine}}.  % crlf {end_token, {'$end', TokenLine}}..
    skip_token.

\{ :
    {token, {'{',  TokenLine}}.

\} :
    {token, {'}',  TokenLine}}.

\( :
    {token, {'(',  TokenLine}}.

\) :
    {token, {')',  TokenLine}}.

{LITERAL}+ :
    % {token, {'LITERAL', TokenLine, TokenChars}}.
    skip_token.

Erlang code.

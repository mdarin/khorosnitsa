
defmodule Khorosnitsa.Formater do
  @moduledoc """
  Documentation
  """

  # alias Khorosnitsa.{Mem, StackComputer}
  # alias Khorosnitsa.Mem

  require Logger

  def generate_code(ast, depth) do
    ast
    |> traverse_exprs(depth)
    |> IO.inspect(label: :buffer)
    |> Enum.join("\n")
  end

  def traverse_exprs(exprs, depth) do
    for expr <- exprs, into: [] do
      # IO.inspect(expr, label: :elem)
      handle_expr(expr, depth)
    end
  end

  def handle_expr(elem, depth) do
    IO.inspect(elem, label: :handle)
    # TODO: сделать наверное клозы вместо case альтернатив
    case elem do
      {
        "if",
        {"(", expr, ")"},
        {"begin", if_exprs, "end"},
        "else",
        {"begin", else_exprs, "end"}
      } ->
        IO.puts("if else")
        indent(depth) <>
          "if " <>
          "(" <>
          handle_expr(expr, 0) <>
          ") {\n" <>
          generate_code(if_exprs, depth + 1) <>
          indent(depth) <>
          "} else {\n" <>
          generate_code(else_exprs, depth + 1) <>
          indent(depth) <>
          "}"
      {
        "if",
        {"(", expr, ")"},
        {"begin", exprs, "end"}
      } ->
        IO.puts("if")

        indent(depth) <>
          "if " <>
          "(" <>
          handle_expr(expr, 0) <>
          ") {\n" <>
          generate_code(exprs, depth + 1) <>
          indent(depth) <>
          "}"

      {
        "while",
        {"(", expr, ")"},
        {"begin", exprs, "end"}
      } ->
        IO.puts("while")

        indent(depth) <>
          "while " <>
          "(" <>
          handle_expr(expr, 0) <>
          ") {\n" <>
          generate_code(exprs, depth + 1) <>
          indent(depth) <>
          "}"

      {
        "func",
        {func, "(", expr, ")"},
        {"begin", exprs, "end"}
      } ->
        IO.puts("func #{inspect(func)} ( #{inspect(expr)} ) { #{inspect(exprs)} }")

        indent(depth) <>
          "func " <>
          func <>
          "(" <>
          handle_expr(expr, 0) <>
          ") {\n" <>
          generate_code(exprs, depth + 1) <>
          indent(depth) <>
          "}"

      {"(", expr, ")"} ->
        IO.puts(" (e) #{inspect(expr)} ")
        indent(depth) <> "(" <> handle_expr(expr, 0) <> ")"

      {func, "(", expr, ")"} ->
        IO.puts("call #{inspect(func)} ( #{inspect(expr)} )")
        indent(depth) <> func <> "(" <> handle_expr(expr, 0) <> ")"

      {var, "=", expr} ->
        IO.inspect(expr, label: :assign)
        indent(depth) <> var <> " = " <> handle_expr(expr, 0)

      {expr1, op, expr2} ->
        # это обычное выражение
        IO.puts("expr <e op e> e: #{inspect(expr1)} op: #{inspect(op)} e2: #{inspect(expr2)}")
        indent(depth) <>
          handle_expr(expr1, 0) <> " " <> to_string(op) <> " " <> handle_expr(expr2, 0)

      nil ->
        # *skip*
        ""

      value when is_list(value) ->
        IO.puts("ARGS")
        # это аргументы функции и они тоже выражения
        # по существу, список аргументов это тот же список выражений, но специальный случай
        Enum.reduce_while(value, [], fn
          nil, acc -> {:halt, Enum.reverse(acc)}
          arg, acc -> {:cont, [handle_expr(arg, 0) | acc]}
        end)
        |> IO.inspect(label: :args)
        |> Enum.join(", ")

      value ->
        IO.puts("VALUE")
        indent(depth) <>
          to_string(value)
    end
  end

  def create_ouput_file(buffer) do
    IO.inspect(buffer, label: :written_buffer)
    # create file(or rewrite)
    File.write("./prog1_gen.zalu", buffer, [:write, :binary])
  end

  def indent(n) do
    if n >= 0 do
      "\t"
      |> List.duplicate(n)
      |> Enum.join("")
    else
      ""
    end
  end
end

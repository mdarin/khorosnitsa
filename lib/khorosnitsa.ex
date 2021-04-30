defmodule Khorosnitsa do
  @moduledoc """
  Documentation for `Khorosnitsa`.
  """
  require Logger
  require File

  alias Khorosnitsa.Mem

  # import File

  @doc """
  Hello world.

  ## Examples

      iex> Khorosnitsa.hello()
      :world

  """
  def hello do
    :world
  end

  def main(args) do
    Mem.start_link()

    args
    |> parse_args
    |> process
  end

  def parse_args(args) do
    options = OptionParser.parse(args, switches: [key: :string])

    case options do
      {[source: source], _, _} -> [source: source]
      {[name: name], _, _} -> [name: name]
      {[help: true], _, _} -> :help
      _ -> :help
    end
  end

  def process(name: name) do
    IO.puts("Hello, #{name}! You're awesome!!")
  end

  def process(source: source) do
    # stream =
    # result =
    # source
    # |> File.stream!()
    # |> Enum.map(&String.trim/1)

    result =
      source
      |> File.read!()
      |> String.to_charlist()
      |> :kho_lexer.string()
      |> IO.inspect(label: :tokenized)

    {:ok, tokens, _endline} = result

    tokens
    |> :kho_parser.parse()
    |> IO.inspect(label: :parsed)

    prog = Mem.dump()

    for inst <- prog do
      IO.inspect(inst, label: :inst)
    end

    execute(prog)
  end

  def process(:help) do
    IO.puts("""
      Usage:
      ./awesome_cli --name [your name]

      Options:
      --help  Show this help message.

      Description:
      Prints out an awesome message.
    """)

    System.halt(0)
  end

  @doc """
  «шина данных» (data bus),
  «стек данных» ( DS ),
  «стек адресов возврата» или просто «стек возврата» ( RS ),
  «арифметическо-логическое устройство» ( ALU ) с регистром «вершина стека» ( TOS ),
  «счетчик программы» ( PC ),
  «программная память» с «регистром адреса памяти» ( MAR ),
  управляющая логика с «регистром инструкций» ( IR )
  и секция «ввода-вывода» ( I/O ).
  """
  def execute(prog) do
    # DS - data stack
    ds = []
    # Simply put, shadow register is a register devised within the stack computer
    # for purpose of holding certain data to be used later.
    # The name "Shadow" implies to duplicate some value and use it again - so it wont get lost.
    shadow = []
    depth = 0
    result = exec(prog, ds, shadow, depth)
    result
  end

  # Стековая машина Молния(ML0) или Феликс
  defp exec([instruction | prog], ds, shadow, depth) do
    IO.puts("""
    ->PROGRAM DEPTH[#{inspect(depth)}]
      SHADOW #{inspect(shadow)}
      DATA STACK #{inspect(ds)}
      INSTRUCTIONS #{inspect([instruction | prog])}
    """)

    case instruction do
      :halt ->
        IO.puts("HALT -> DS #{inspect(ds)}")

        IO.puts("""
        ** RESULT
          DS dump:
        """)

        for i <- ds, do: IO.inspect(i)
        ds

      :done ->
        IO.puts("DONE -> DS #{inspect(ds)}")

        # TODO тут можно от глубины сделать, если глубина 0 то пропускать если не 0 то вызвращать управление и уменьшать глубину стека вызовов
        # TODO скорей всего надо будет оставить только команду halt, они похожи
        IO.puts("""
          DS dump:
        """)

        for i <- ds, do: IO.inspect(i)

        case shadow do
          {:loop, loop_code} ->
            # если это цикл, запустить код снова из теневого регистра
            exec(loop_code, ds, shadow, depth)

          _ ->
            # иначе это конец сегмента
            ds
        end

      :var ->
        [variable | rest] = ds
        value = Mem.get(variable)
        exec(prog, [value | rest], shadow, depth)

      :const ->
        [constant | rest] = ds
        value = Mem.get_const(constant)
        exec(prog, [value | rest], shadow, depth)

      :prn ->
        # вывести значение вершины стака(TOS - top of stack)
        # на самом деле это аргумент функции print ARG, он попадает на вершину
        # и команда вывода снимает его с вершины и выводит на устройство вывода
        [tos | rest] = ds

        IO.puts("""

            **
            ** #{inspect(tos)}
            **
        """)

        exec(prog, rest, shadow, depth)

      [:loop_while | _code] = loop_code ->
        # вызов вложеннойсти (по сути это вход в подпрограмму)
        IO.puts("'-> ENTER")

        # помещаем в теневой регистр копию набора инструкций цикла
        shadow = {:loop, loop_code}
        ds0 = exec(loop_code, [], shadow, depth + 1)
        IO.puts("<-' RETURN")
        ds = Enum.concat(ds0, ds)
        exec(prog, ds, shadow, depth)

      :loop_while ->
        # *NOP* skipped
        exec(prog, ds, shadow, depth)

      [:if_then | _code] = if_code ->
        # вызов вложеннойсти (по сути это вход в подпрограмму)
        IO.puts("'-> ENTER")
        # emtpy DS, shadow -> [] | else_code
        # проверить нет ли ветки альтернативы
        # если она есть, то ПЕРЕместить её в теневой регистр
        # в случае, если условие окажется ложным, выполнется код из теневого регистра(а там будет как раз else_code)
        [next_instruction | rest_prog] = prog

        shadow =
          case next_instruction do
            [:else_then | _code] = else_code ->
              {:else, else_code}

            _ ->
              []
          end

        ds0 = exec(if_code, [], shadow, depth + 1)
        IO.puts("<-' RETURN")
        ds = Enum.concat(ds0, ds)
        exec(rest_prog, ds, shadow, depth)

      :if_then ->
        # *NOP* skipped
        exec(prog, ds, shadow, depth)

      [:else_then | _code] = else_code ->
        # вызов вложеннойсти (по сути это вход в подпрограмму)
        IO.puts("'-> ENTER")
        # emtpy DS, empty shadow
        ds0 = exec(else_code, [], [], depth + 1)
        IO.puts("<-' RETURN")
        ds = Enum.concat(ds0, ds)
        exec(prog, ds, shadow, depth)

      :else_then ->
        # *NOP* skipped
        exec(prog, ds, shadow, depth)

      :cond_expr ->
        # я думаю что надо убрать маркер body и проверку кондиции делать под маркером cond_exrp, тут
        # skip
        #   exec(prog, ds, shadow)
        # :body ->
        # здесь проверяется условие цикла
        # условие как результат вычисления выражения, расположена на вершине стека
        case ds do
          [tos | rest_ds] ->
            case tos do
              true ->
                # продолжить выполнение программы
                exec(prog, rest_ds, shadow, depth)

              false ->
                # если это условный оператор, то запустить альтернативную ветку
                # иначе это цикл и его пора завершать
                case shadow do
                  {:else, else_code} ->
                    exec(else_code, rest_ds, [], depth)

                  _ ->
                    rest_ds
                end
            end

          _ ->
            ds
        end

      :mov ->
        [variable, value | rest] = ds
        Mem.put(variable, value)
        exec(prog, rest, shadow, depth)

      :lt ->
        [operand2, operand1 | rest] = ds
        result = operand1 < operand2
        exec(prog, [result | rest], shadow, depth)

      :gt ->
        [operand2, operand1 | rest] = ds
        result = operand1 > operand2
        exec(prog, [result | rest], shadow, depth)

      :ge ->
        [operand2, operand1 | rest] = ds
        result = operand1 >= operand2
        exec(prog, [result | rest], shadow, depth)

      :le ->
        [operand2, operand1 | rest] = ds
        result = operand1 <= operand2
        exec(prog, [result | rest], shadow, depth)

      :eq ->
        [operand2, operand1 | rest] = ds
        result = operand1 == operand2
        exec(prog, [result | rest], shadow, depth)

      :ne ->
        [operand2, operand1 | rest] = ds
        result = operand1 != operand2
        exec(prog, [result | rest], shadow, depth)

      # :ge ->
      #   [operand2, operand1 | rest] = ds
      #   result = operand1 >= operand2
      #   IO.inspect(
      #       "GE Pop #{inspect(operand1)}, Pop #{inspect(operand2)} -> Push TOS . #{inspect(result)}"
      #     )
      #   exec(prog, [result | rest], shadow, depth)
      :add ->
        [operand2, operand1 | rest] = ds
        result = operand1 + operand2
        exec(prog, [result | rest], shadow, depth)

      :sub ->
        # (!) Не забываем что в стеке операнды лежат в обратном порядке!
        [operand2, operand1 | rest] = ds
        result = operand1 - operand2
        exec(prog, [result | rest], shadow, depth)

      :mul ->
        [operand2, operand1 | rest] = ds
        result = operand1 * operand2
        exec(prog, [result | rest], shadow, depth)

      # -----------
      # / as arithmetic operators, plus the functions div/2 and rem/2 for integer division and remainder.
      # -----------
      :dond ->
        # /	Division of numerator by denominator
        [operand2, operand1 | rest] = ds
        result = operand1 / operand2
        exec(prog, [result | rest], shadow, depth)

      :remi ->
        # rem Remainder of dividing the first number by the second
        [operand2, operand1 | rest] = ds
        result = rem(operand1, operand2)
        exec(prog, [result | rest], shadow, depth)

      :divi ->
        # div The div component will perform the division and return the integer component.
        [operand2, operand1 | rest] = ds
        result = div(operand1, operand2)
        exec(prog, [result | rest], shadow, depth)

      :neg ->
        [operand | rest] = ds
        result = -operand
        exec(prog, [result | rest], shadow, depth)

      # это скорей всего лиетерал(LIT или lit)
      symbol ->
        exec(prog, [symbol | ds], shadow, depth)
    end
  end

  defp exec([], ds, _, _) do
    ds
  end
end

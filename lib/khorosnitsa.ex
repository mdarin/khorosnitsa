defmodule Khorosnitsa do
  @moduledoc """
  Documentation for `Khorosnitsa`.
  """
  use Bitwise

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
    # {:ok, pid} =
    Mem.start_link()
    # :sys.trace(pid, :true)

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
    # «стек адресов возврата»
    rs = []
    # Simply put, shadow register is a register devised within the stack computer
    # for purpose of holding certain data to be used later.
    # The name "Shadow" implies to duplicate some value and use it again - so it wont get lost.
    shadow = []

    # Область видимости (англ. scope) в программировании — часть программы,
    # в пределах которой идентификатор, объявленный как имя некоторой программной сущности
    # (обычно — переменной, типа данных или функции), остаётся связанным с этой сущностью,
    # то есть позволяет посредством себя обратиться к ней.
    global_scope = %{}
    scopes = [global_scope]
    # глубина стека вызовов
    depth = 0
    result = exec(prog, ds, rs, shadow, scopes, depth)
    result
  end

  # Стековая машина Молния(ML0) или Феликс
  defp exec([instruction | prog], ds, rs, shadow, [_front_scope | back_scopes] = scopes, depth) do
    # IO.puts("""
    # ->PROGRAM DEPTH[#{inspect(depth)}]
    #   SCOPES #{inspect(scopes)}
    #   SHADOW #{inspect(shadow)}
    #   DATA STACK #{inspect(ds)}
    #   RETURN STACK #{inspect(rs)}
    #   INSTRUCTIONS #{inspect([instruction | prog])}
    # """)

    # IO.puts("#{inspect instruction}\t#{inspect ds} #{inspect scopes}")

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
            nested_scope = %{}
            exec(loop_code, ds, rs, shadow, [nested_scope | scopes], depth + 1)

          _ ->
            # иначе это конец сегмента
            # необходимо удалить страницу области видимости с вершины
            {ds, back_scopes}
        end

      :mov ->
        # следить за областью видимости
        # если это нулевой уровень, то работать с памятью(регистрами)
        # если это локальня область, то сохранить на страницу области
        [variable, value | rest] = ds
        # case depth do
        #   0 ->
        #     Mem.put(variable, value)
        #     exec(prog, rest, rs, shadow, scopes, depth)
        #   _ ->
        scopes = update_scopes(scopes, variable, value)
        exec(prog, rest, rs, shadow, scopes, depth)

      :var ->
        # Переменные имеют области видимости
        # Области видимости имеют страничную организацию в виде стека
        # На вершине стека располагется страница с агрументами функции, если они есть
        #   (пока я сделал что это общая область аргументов и переменных в теле функции)
        # В середине стека располагаются страницы с локальными переменными
        # На дне стека всегда страница с глобальными переменными,
        # эти переменные являются регисрами и к ним можно получить доступ
        # даже после завершения работы программы
        # -- про проинцип пирамиды описано в файле грамматики
        [variable | rest] = ds
        # case depth do
        #   0 ->
        #     value = Mem.get(variable)
        #     exec(prog, [value | rest], rs, shadow, scopes, depth)
        #   _ ->
        value = lookup_scopes(scopes, variable)
        exec(prog, [value | rest], rs, shadow, scopes, depth)

      # end

      :const ->
        [constant | rest] = ds
        value = Mem.get_const(constant)
        exec(prog, [value | rest], rs, shadow, scopes, depth)

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

        exec(prog, rest, rs, shadow, scopes, depth)

      [:loop_while | _code] = loop_code ->
        # вызов вложеннойсти (по сути это вход в подпрограмму)
        # IO.puts("'-> ENTER")
        # помещаем в теневой регистр копию набора инструкций цикла
        shadow = {:loop, loop_code}
        # empty DS, empty RS, shadow hold loop code
        nested_scope = %{}
        {ds0, scopes0} = exec(loop_code, [], [], shadow, [nested_scope | scopes], depth + 1)
        # IO.puts("<-' RETURN")
        ds = Enum.concat(ds0, ds)
        # Logger.debug(" == = = = = = = = . #{inspect prog}")
        exec(prog, ds, rs, shadow, scopes0, depth)

      :loop_while ->
        # *NOP* skipped
        exec(prog, ds, rs, shadow, scopes, depth)

      [:if_then | _code] = if_code ->
        # вызов вложеннойсти (по сути это вход в подпрограмму)
        # IO.puts("'-> ENTER")
        # emtpy DS, shadow -> [] | else_code
        # проверить нет ли ветки альтернативы
        # если она есть, то ПЕРЕместить её в теневой регистр
        # в случае, если условие окажется ложным, выполнется код из теневого регистра(а там будет как раз else_code)
        [next_instruction | rest_prog] = prog

        case next_instruction do
          [:else_then | _code] = else_code ->
            shadow = {:else, else_code}
            nested_scope = %{}
            {ds0, scopes0} = exec(if_code, [], rs, shadow, [nested_scope | scopes], depth + 1)
            # IO.puts("<-' RETURN")
            ds = Enum.concat(ds0, ds)
            exec(rest_prog, ds, rs, shadow, scopes0, depth)

          _ ->
            shadow = []
            nested_scope = %{}
            {ds0, scopes0} = exec(if_code, [], rs, shadow, [nested_scope | scopes], depth + 1)
            # IO.puts("<-' RETURN")
            ds = Enum.concat(ds0, ds)
            exec(prog, ds, rs, shadow, scopes0, depth)
        end

      :if_then ->
        # *NOP* skipped
        exec(prog, ds, rs, shadow, scopes, depth)

      [:else_then | _code] = else_code ->
        # вызов вложеннойсти (по сути это вход в подпрограмму)
        # IO.puts("'-> ENTER")
        # emtpy DS, RS, shadow
        nested_scope = %{}
        {ds0, scopes0} = exec(else_code, [], [], [], [nested_scope | scopes], depth + 1)
        # IO.puts("<-' RETURN")
        ds = Enum.concat(ds0, ds)
        exec(prog, ds, rs, shadow, scopes0, depth)

      :else_then ->
        # *NOP* skipped
        exec(prog, ds, rs, shadow, scopes, depth)

      :cond_expr ->
        # здесь проверяется условие цикла и условие ветвления
        # условие как результат вычисления выражения, расположено на вершине стека(в регистре TOS)

        # Для корректной работы требуется хранить и понимать теукщее состояние
        # состояний может быть несколько
        # - цикл
        # - условие if
        # - условие if-else

        # [INFO]
        # if-elif-else это по сути тотже if-else

        # Цикл - это звено в цепочке команд содержащее в себе вложенную цепочку команд
        # Признак цикла - наличие кода в теневом регистре, возмоно с меткой "loop"
        # Вход в цикл - это метка "loop_while" или иная.
        # При обнаружении этой метки код цикла помещается в теневой регистр и передаётся,
        # как аргумент программы в экземпляр функции "exec(loopcode, ds, shadow=loopcode или {loop, loopcode})"
        # Выходы
        # 1й выход возможен при достижении конца сегмента кода цикла
        # 2й выход возможен при не выполнении условия цикла, при этом часть сегмента кода цикла выполняется!
        # При этом должно НЕКОСНИТЕЛЬНО выполнятся правило, один воход = один выход
        # Требуется реализовать переход при не выполнении цикла в точку завершения сегмента("done")

        # если это цикл - теневой регистр не пуст



        # если это цикл

        # если это ветвление

        case ds do
          [tos | rest_ds] ->
            case tos do
              true ->
                # продолжить выполнение программы
                exec(prog, rest_ds, rs, shadow, scopes, depth)

              false ->
                # если это условный оператор, то запустить альтернативную ветку
                # иначе это цикл и его пора завершать
                case shadow do
                  {:else, else_code} ->
                    exec(else_code, rest_ds, rs, [], scopes, depth)

                  _ ->
                    # {rest_ds, back_scopes}
                    exec([:done], rest_ds, rs, [], scopes, depth)
                end
            end

          _ ->
            # {ds, scopes}
            exec([:done], ds, rs, [], scopes, depth)
        end

      :lt ->
        [operand2, operand1 | rest] = ds
        result = operand1 < operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :gt ->
        [operand2, operand1 | rest] = ds
        result = operand1 > operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :ge ->
        [operand2, operand1 | rest] = ds
        result = operand1 >= operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :le ->
        [operand2, operand1 | rest] = ds
        result = operand1 <= operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :eq ->
        [operand2, operand1 | rest] = ds
        result = operand1 == operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :ne ->
        [operand2, operand1 | rest] = ds
        result = operand1 != operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :add ->
        [operand2, operand1 | rest] = ds
        result = operand1 + operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :sub ->
        # (!) Не забываем что в стеке операнды лежат в обратном порядке!
        [operand2, operand1 | rest] = ds
        result = operand1 - operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :mul ->
        [operand2, operand1 | rest] = ds
        result = operand1 * operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      # -----------
      # / as arithmetic operators, plus the functions div/2 and rem/2 for integer division and remainder.
      # -----------
      :dond ->
        # /	Division of numerator by denominator
        [operand2, operand1 | rest] = ds
        result = operand1 / operand2
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :remi ->
        # rem Remainder of dividing the first number by the second
        [operand2, operand1 | rest] = ds
        result = rem(operand1, operand2)
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :divi ->
        # div The div component will perform the division and return the integer component.
        [operand2, operand1 | rest] = ds
        result = div(operand1, operand2)
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :neg ->
        [operand | rest] = ds
        result = -operand
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :pow ->
        [operand2, operand1 | rest] = ds
        {m, f} = Mem.get_builtin('pow')
        result = apply(m, f, [operand1, operand2])
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :shr ->
        [operand2, operand1 | rest] = ds
        result = Bitwise.bsr(operand1, operand2)
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :shl ->
        [operand2, operand1 | rest] = ds
        result = Bitwise.bsl(operand1, operand2)
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :bconj ->
        [operand2, operand1 | rest] = ds
        result = Bitwise.band(operand1, operand2)
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :bif ->
        # Built-In Functions (BIFs)
        [operand2, operand1 | rest] = ds
        {m, f} = Mem.get_builtin(operand2)
        result = apply(m, f, [operand1])
        exec(prog, [result | rest], rs, shadow, scopes, depth)

      :call ->
        [function | ds1] = ds
        # получить код функции по ссылке
        func_params = Mem.call_func(function)
        # вызов подпрограммы
        # IO.puts("'-> ENTER")
        {args, ds2} = Enum.split(ds1, func_params.arity)
        # Несоответсвие параметров это фатальная ошибка
        true = length(args) == func_params.arity

        # соотнести артументы функции и их имена переменных,
        # а затем поместить это в область видимости
        nested_scope =
          for {variable, value} <- Enum.zip(func_params.args, args),
              into: %{},
              do: {variable, value}

        # emtpy DS, shadow
        # в RS передаются значения аргументов
        # [i] To access atom keys, one may also use the map.key notation.
        {ds0, scopes0} = exec(func_params.code, [], rs, [], [nested_scope | scopes], depth + 1)
        # IO.puts("<-' RETURN")
        # по сути это возврат результата из подпрограммы, результат оказывается на вершине стека
        ds = Enum.concat(ds0, ds2)

        # возврат из подпрограммы в основной поток исполнения
        # empty RS
        exec(prog, ds, [], shadow, scopes0, depth)

      # это скорей всего лиетерал(LIT или lit)
      symbol ->
        exec(prog, [symbol | ds], rs, shadow, scopes, depth)
    end
  end

  defp exec([] = _prog, ds, _rs, _shadow, _scopes, _depth) do
    ds
  end

  ##
  ## internals
  #

  def push_nested_scope(scopes) do
    nested_scope = %{}
    [nested_scope | scopes]
  end

  def pop_nested_scope([_nested_scope | rest_scopes] = _scopes) do
    rest_scopes
  end

  def lookup_scopes(scopes, variable) do
    # просмотреть страницы пространств имён
    # value =
    Enum.reduce_while(scopes, :undefined, fn
      scope, acc ->
        case Map.get(scope, variable) do
          nil -> {:cont, acc}
          value -> {:halt, value}
        end
    end)

    # если на страцинах такой переменной не нашлось,
    # то попробовать поискать среди глобальных переменных
    # case value do
    #   :undefined ->
    #     Mem.get(variable)
    #   value ->
    #     value
    # end
  end

  def get_mock_scopes do
    [
      %{'a' => 5, 'd' => 42},
      %{'a' => 4},
      %{'a' => 3},
      %{'a' => 2, 'c' => 42},
      %{'a' => 1, 'b' => 42}
    ]
  end

  def update_scopes(scopes, variable, value) do
    # Просматриваются страницы областей видимости начиная с вершины стека страниц
    # обновляется переменная в ближайшей к вершине области видимости
    # если такой переменной нет ни в одной области видимости, то она создаётся в текущей странице(на вершине)

    {is_updated, pos, viewed_scopes} =
      r =
      Enum.reduce_while(scopes, {false, 0, []}, fn
        scope, {_is_updated, count, acc} ->
          case Map.get(scope, variable, :undefined) do
            :undefined ->
              # если переменной нет
              {:cont, {false, count + 1, [scope | acc]}}

            _ ->
              # обновить значение переменной и остановиться
              # зафиксирвоать номер страницы и выставить флаг
              scope = Map.put(scope, variable, value)
              {:halt, {true, count + 1, [scope | acc]}}
          end
      end)

    case is_updated do
      true ->
        # если флаг установлен
        viewed_scopes = Enum.reverse(viewed_scopes)
        {_skip, tail} = Enum.split(scopes, pos)
        Enum.concat(viewed_scopes, tail)

      _ ->
        # если флаг сброшен, то поместить переменную в страницу на вершине
        [scope | rest_scopes] = scopes
        scope = Map.put(scope, variable, value)
        [scope | rest_scopes]
    end
  end
end

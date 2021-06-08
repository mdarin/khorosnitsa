defmodule Khorosnitsa do
  @moduledoc """
  Documentation for `Khorosnitsa`.
  """
  use Bitwise

  require Logger
  require File
  require Regex

  alias Khorosnitsa.{Mem, StackComputer, Formater}

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
    |> IO.inspect(label: :parsed_args)
    |> process
  end

  def parse_args(args) do
    options =
      OptionParser.parse(args, switches: [key: :string])
      |> IO.inspect(label: :options)

    case options do
      {[source: source], _, _} -> [source: source]
      {[name: name], _, _} -> [name: name]
      {[help: true], _, _} -> :help
      _ -> :repl
    end
  end

  @doc """
  # Командный интерфейс интерпретатора Ragdon для языка Zalupashka

  По умолчанию
  :repl - Работать в режиме диалога или так называемого цикла чтения-вычисления-печати (англ. read-eval-print loop, REPL)
  """
  def process(name: name) do
    IO.puts("Hello, #{name}! You're awesome!!")
  end

  def process(source: source) do
    # stream =
    # result =
    # source
    # |> File.stream!()
    # |> Enum.map(&String.trim/1)

    #  произвести лексический анализ
    result =
      source
      |> File.read!()
      |> String.to_charlist()
      |> :kho_lexer.string()
      |> IO.inspect(label: :tokenized)

    # здесь можно сделать обработку ошибок
    {:ok, tokens, _endline} = result

    # произвести синтаксический анализ
    result =
      tokens
      |> normalize_tokens()
      |> :kho_parser.parse()
      |> IO.inspect(label: :parsed)

    # получить дерево разбора после синтаксического анализа
    {:ok, ast} = result

    # генерация кода (здесь обратно в zalupashku, по сути это форматер получается)
    ast
    |> Formater.generate_code(0)
    |> Formater.create_ouput_file()

    # получить дамп программы из памяти(память обнулится)
    prog = Mem.dump()

    # генерация ассемблера для интерпретатора
    # ==== начало генерации ассемблера
    intermediate_code =
      prog
      |> List.flatten()
      |> IO.inspect(label: :flattened)

    # ----- обход таблицы функций
    func_list =
      Mem.get_functions
      |> IO.inspect(label: :funcs)
      |> Map.to_list()
      |> IO.inspect(label: :func_list)

    func_defs = for {func_name, func_def} <- func_list, into: [] do
      [func_name <> ":" | func_def.code]
      |> List.flatten()
      |> IO.inspect(label: :func_def)
    end

    IO.inspect(func_defs, label: :defuncs)
    # -----------

    # вставить определения функций(подпрограмм в код основной программы)
    intermediate_code =
      [intermediate_code | func_defs]
      |> Enum.concat()
      |> Enum.join("\n")
      |> IO.inspect(label: :joined)

    # out intermediate code into a file
    File.write("./intermediate_code", intermediate_code, [:write, :binary])
    # === конец генерации ассемблера


    # вывести на экран программу в виде инструкции
    for inst <- prog do
      IO.inspect(inst, label: :inst)
    end

    # запустить программу на выполнение
    result = StackComputer.execute(prog)

    # обработать результат
    Logger.debug(" ===[EXEC]=== result -> #{inspect(result)}")
    result
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

  def process(:repl) do
    # lineno = 1
    buffer = []
    prompt = "|> "
    cli_loop(prompt, buffer)
  end

  @doc """
    Нужно убрать лишние переводы строки потому что лексер не может этого сделать
  """
  def normalize_tokens(tokens) do
    {_, filtered} = Enum.reduce(tokens, {:skip, []}, fn
      {:LF, _line}, {:skip, acc} -> {:skip, acc}
      {:LF, _line} = token, {:keep, acc} -> {:skip, [token | acc]}
      token, {_state, acc} -> {:keep, [token | acc]}
    end)
    # IO.inspect(Enum.reverse(filtered), label: :normalized)
    Enum.reverse(filtered)
  end

  @doc """
  Простая стековая машина реагирующая на открывающиеся и закрывающиеся скобки, кавычки и пр
  """
  def cli_loop(prompt, buffer) do
    line = IO.gets(prompt)

    buffer = List.insert_at(buffer, -1, line)

    {:ok, tokens, _endline} =
      List.to_string(buffer)
      |> IO.inspect(label: :buffer)
      |> String.to_charlist()
      |> :cli_lexer.string()
      |> IO.inspect(label: :tokenized)

    result =
      tokens
      |> :cli_parser.parse()
      |> IO.inspect(label: :parsed)

    case result do
      {:ok, :completed} ->
        # prepare expr

        buffer = buffer |> List.to_string()
        expr = Regex.replace(~r/[\n]+/, buffer, "") <> "\n"
        IO.inspect(expr, label: :expr)

        # evaluate expr
        #  произвести лексический анализ
        result =
          expr
          |> String.to_charlist()
          |> :kho_lexer.string()
          |> IO.inspect(label: :tokenized)

        # здесь можно сделать обработку ошибок
        {:ok, tokens, _endline} = result

        # произвести синтаксический анализ
        result =
          tokens
          |> normalize_tokens()
          |> :kho_parser.parse()
          |> IO.inspect(label: :parsed)

        # получить дерево разбора после синтаксического анализа
        {:ok, _ast} = result

        # получить дамп программы из памяти(память обнулится)
        prog = Mem.dump()

        # запустить программу на выполнение
        StackComputer.execute(prog)

        # reset buffer and restart loop
        cli_loop("|> ", [])

      {:ok, :continue} ->
        # accumulate buffer
        cli_loop("|>> ", buffer)

      _ ->
        Logger.error("Malformed string: #{inspect(line)} buffer: #{inspect(buffer)}")
        cli_loop(prompt, [])

    end
  end
end




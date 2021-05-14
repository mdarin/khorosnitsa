defmodule Khorosnitsa do
  @moduledoc """
  Documentation for `Khorosnitsa`.
  """
  use Bitwise

  require Logger
  require File

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

    #  произвести лексический анализ
    result =
      source
      |> File.read!()
      |> String.to_charlist()
      |> :kho_lexer.string()
      |> IO.inspect(label: :tokenized)

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
    intermediate_code =
      prog
      |> List.flatten()
      |> IO.inspect(label: :flattened)
      # |> Enum.join("\n")
      # |> IO.inspect(label: :joined)

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


    # вывести на экран программу в виде инструкции
    for inst <- prog do
      IO.inspect(inst, label: :inst)
    end

    # запустить программу на выполнение
    result = StackComputer.execute(prog)

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

end

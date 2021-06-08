defmodule KhorosnitsaTest do
  use ExUnit.Case, async: true, colors: :enabled
  doctest Khorosnitsa

  require Logger
  require File

  alias Khorosnitsa.{Mem, StackComputer}

  @model_1 [
        {:ok, "01_delims.zalu"},
        {:ok, "02_fibo.zalu"},
        {:ok, "03_fucn_and_branch.zalu"},
        {:ok, "04_func_and_cycle.zalu"},
        {:ok, "05_mixed_program.zalu"},
        {:ok, "06_proc_func_recursion.zalu"},
        {:ok, "07_scopes.zalu"}
      ]

  @model_2 [
        {[300, 200, 100, 60, 4, 3, 2], "01_delims.zalu"},
        {[89, 55, 34, 21, 13, 8, 5, 3, 2, 1, 1, 0], "02_fibo.zalu"},
        {[3], "03_fucn_and_branch.zalu"},
        {[4], "04_func_and_cycle.zalu"},
        {[2], "05_mixed_program.zalu"},
        {[40318.045405288554, 5039.686258179277, 40320, 5040], "06_proc_func_recursion.zalu"},
        {[:undefined, 20, 6, 10, 1], "07_scopes.zalu"}
      ]



  setup_all do
    IO.puts("This is only run once.")
    {:ok, pid} = Mem.start_link()

    _contex = %{
      memory_pid: pid
    }
  end

  # on_exit fn ->
  #   IO.puts "This is invoked once the test is done."
  #   Mem.stop
  # end

  test "greets the world" do
    assert Khorosnitsa.hello() == :world
  end

  # https://hexdocs.pm/ex_unit/ExUnit.Case.html#describe/2
  # mix test --only describe:"String.capitalize/1"

  # describe "String.capitalize/1" do
  #   test "first grapheme is in uppercase" do
  #     assert String.capitalize("hello") == "Hello"
  #   end

  #   test "converts remaining graphemes to lowercase" do
  #     assert String.capitalize("HELLO") == "Hello"
  #   end
  # end

  # группа лексический анализ
  describe "Lexer" do
    test "test hello lexer" do
      scanned = get_sources() |> scan_sources_by_lexer()
      Logger.info("scanned #{inspect(scanned)}")

      model = @model_1
      assert model == scanned
    end
  end

  # группа синтаксичесий анализ
  describe "Parser" do
    test "test hello parser" do
      parsed =
        get_sources()
        |> scan_tokens()
        |> parse_tokens()

      Logger.info("parsed #{inspect(parsed)}")

      model = @model_1
      assert model == parsed
    end
  end

  # группа исполнение программы
  describe "Interpreter" do
    test "test hello interpreter" do
      executed =
        get_sources()
        |> scan_tokens()
        |> prepare_and_execute_programs()

      Logger.info("executed #{inspect(executed)}")

      model = @model_2
      assert model == executed
    end
  end

  ##
  ## internals
  #

  # счиать исходные тексты тестовых программ
  defp get_sources() do
    "./test"
    |> File.ls!()
    |> Enum.sort()
    |> Enum.filter(fn file -> file =~ ~r/[.]zalu/ end)
  end

  # пропустить считанные файлы чезер сканер(лексический анализатор или lexer)
  defp scan_sources_by_lexer(sources) do
    for source <- sources, into: [] do
      result =
        ("./test/" <> source)
        |> File.read!()
        |> String.to_charlist()
        |> :kho_lexer.string()

      case result do
        {:ok, _tokens, _endline} -> {:ok, source}
        _ -> {:error, source}
      end
    end
  end

  # получить токены из считанных файлов пропущенных чезер сканер(лексический анализатор или lexer)
  defp scan_tokens(sources) do
    for source <- sources, into: [] do
      result =
        ("./test/" <> source)
        |> File.read!()
        |> String.to_charlist()
        |> :kho_lexer.string()

      {result, source}
    end
  end

  defp parse_tokens(scanned) do
    for {{:ok, tokens, _}, source} <- scanned, into: [] do
      result =
        tokens
        |> Khorosnitsa.normalize_tokens()
        |> :kho_parser.parse()
      # Logger.debug("tokens #{inspect result} source #{inspect source}")
      case result do
        {:ok, _ast} -> {:ok, source}
        _ -> {:error, source}
      end
    end
  end

  defp prepare_and_execute_programs(scanned) do
    for {{:ok, tokens, _}, source} <- scanned, into: [] do
      tokens
      |> Khorosnitsa.normalize_tokens()
      |> :kho_parser.parse()
      prog = Mem.dump()
      result = StackComputer.execute(prog)

      {result, source}
    end
  end
end

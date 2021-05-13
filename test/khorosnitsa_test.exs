defmodule KhorosnitsaTest do
  use ExUnit.Case, async: true, colors: :enabled
  doctest Khorosnitsa

  require Logger
  require File

  alias Khorosnitsa.Mem

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

      model = [
        {:ok, "delims.zalu"},
        {:ok, "fibo.zalu"},
        {:ok, "fucn_and_branch.zalu"},
        {:ok, "func_and_cycle.zalu"},
        {:ok, "mixed_program.zalu"},
        {:ok, "proc_func_recursion.zalu"},
        {:ok, "scopes.zalu"}
      ]

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

      model = [
        {:ok, "delims.zalu"},
        {:ok, "fibo.zalu"},
        {:ok, "fucn_and_branch.zalu"},
        {:ok, "func_and_cycle.zalu"},
        {:ok, "mixed_program.zalu"},
        {:ok, "proc_func_recursion.zalu"},
        {:ok, "scopes.zalu"}
      ]

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

      model = [
        {[300, 200, 100, 60, 4, 3, 2], "delims.zalu"},
        {[89, 55, 34, 21, 13, 8, 5, 3, 2, 1, 1, 0], "fibo.zalu"},
        {[3], "fucn_and_branch.zalu"},
        {[4], "func_and_cycle.zalu"},
        {[2], "mixed_program.zalu"},
        {[40318.045405288554, 5039.686258179277, 40320, 5040], "proc_func_recursion.zalu"},
        {[:undefined, 20, 6, 10, 1], "scopes.zalu"}
      ]

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
      result = Khorosnitsa.execute(prog)

      {result, source}
    end
  end
end

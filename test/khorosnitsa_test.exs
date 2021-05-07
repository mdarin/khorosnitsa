defmodule KhorosnitsaTest do
  use ExUnit.Case, async: true, colors: :enabled
  doctest Khorosnitsa

  require Logger
  require File

  alias Khorosnitsa.Mem

  setup_all do
    IO.puts("This is only run once.")
    {:ok, pid} = Mem.start_link()

    contex = %{
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
        ok: "fibo.zalu",
        ok: "fucn_and_branch.zalu",
        ok: "func_and_cycle.zalu",
        ok: "mixed_program.zalu",
        ok: "proc_func_recursion.zalu",
        ok: "scopes.zalu"
      ]

      assert model == scanned
    end
  end

  # группа синтаксичесий анализ
  describe "Parser" do
    test "test hello parser" do
      parsed = get_sources() |> scan_tokens() |> parse_tokens()
      Logger.info("parsed #{inspect(parsed)}")

      model = [
        ok: "fibo.zalu",
        ok: "fucn_and_branch.zalu",
        ok: "func_and_cycle.zalu",
        ok: "mixed_program.zalu",
        ok: "proc_func_recursion.zalu",
        ok: "scopes.zalu"
      ]

      assert model == parsed
    end
  end

  # группа исполнение программы
  describe "Interpreter" do
    test "test hello interpreter" do
      assert true == true
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
      result = tokens |> :kho_parser.parse()
      # Logger.debug("tokens #{inspect tokens} source #{inspect source}")
      case result do
        {:ok, valid_grammar} -> {:ok, source}
        _ -> {:error, source}
      end
    end
  end
end

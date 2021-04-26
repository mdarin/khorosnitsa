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

  def process([name: name]) do
    IO.puts("Hello, #{name}! You're awesome!!")
  end

  def process([source: source]) do
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

      for inst <- Mem.dump do
        IO.inspect(inst, label: :inst)
      end

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



end

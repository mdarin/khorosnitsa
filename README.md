# Khorosnitsa

Хоросница - это интерпретатор языка Залупашка, выполненный на основе магазинного автомата.

Zalupashka – это простой программируемый интерпретатор для выражений с плавающей точкой.

```text 
凸(￣ヘ￣)
```

## Installation

```bash
clone the project
cd path/to/clonned/dir
mix escript.build
mix test
```

REPL mode

```bash
./khorosnitsa
|> 1 + 1
```

и вы должны увидать 2 как результат вычисления выражения

Также можно передать файл с программой на выполнение

```bash
./khorosnitsa --source ./test/01_delims.zalu
```

Запуск приложения в контейнере

```sh
clone the project
cd path/to/clonned/dir
docker run --rm  -it -v $PWD:/app -w /app elixir:alpine ash
root@container# mix escript.build
root@container# mix test
```

И посмотреть результат работы

Программы на яызыке Залупашка имеют расширение `zalu`. Это конвенция, но не требование

Файлы test/*.zalu содержат примеры программ и заодно являются образцами для тестов

Это наброски собраные в рабочий проект, коорый можно покрутить поизучать.
Не является законченным продуктом.

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `khorosnitsa` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:khorosnitsa, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/khorosnitsa](https://hexdocs.pm/khorosnitsa).

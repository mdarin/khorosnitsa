defmodule Khorosnitsa.Mem do
  @moduledoc """
  Documentation

  :sys.statistics(pid("0.145.0"), true)
  :sys.trace(pid("0.145.0"), true)
  """
  use GenServer

  require Logger

  # Client API

  def start_link do
    # Logger.debug("start memory server")
    GenServer.start_link(__MODULE__, [], name: :mem)
  end

  def stop do
    # Logger.debug("stop memory server")
    GenServer.cast(:mem, :stop)
  end

  # memory API

  def put(key, value) do
    GenServer.cast(:mem, {:put, key, value})
  end

  def get(key) do
    GenServer.call(:mem, {:get, key})
  end

  def is_constant(key) do
    GenServer.call(:mem, {:is_constant, key})
  end

  def get_const(key) do
    GenServer.call(:mem, {:get_const, key})
  end

  def is_builtin(key) do
    GenServer.call(:mem, {:is_builtin, key})
  end

  def get_builtin(key) do
    GenServer.call(:mem, {:get_builtin, key})
  end

  # stack API

  # push(>...items) – добавляет элементы в конец,
  # pop(<...items) – извлекает элемент из конца,
  # shift(items...>) – извлекает элемент из начала,
  # unshift(items...<) – добавляет элементы в начало.

  def push(element) do
    GenServer.cast(:mem, {:push, element})
    # GenServer.call(:mem, {:push, element})
  end

  def pop do
    GenServer.call(:mem, :pop)
  end

  def shift do
    GenServer.call(:mem, :shift)
  end

  def unshift(element) do
    # GenServer.cast(:mem, {:unshift, element})
    GenServer.call(:mem, {:unshift, element})
  end

  def insert(position, element) do
    GenServer.cast(:mem, {:insert, position, element})
  end

  def dump do
    GenServer.call(:mem, :dump)
  end

  def get_depth do
    GenServer.call(:mem, :get_depth)
  end

  def roll_up(position) do
    GenServer.cast(:mem, {:roll_up, position})
  end

  def nested do
    GenServer.cast(:mem, :nested)
  end

  def embed_nested do
    GenServer.cast(:mem, :embed_nested)
  end

  def place_function do
    GenServer.cast(:mem, :place_function)
  end

  def call_func(function) do
    GenServer.call(:mem, {:call, function})
  end

  def is_function(key) do
    GenServer.call(:mem, {:is_function, key})
  end

  def get_functions do
    GenServer.call(:mem, :get_functions)
  end

  # Server callbacks

  @impl true
  def init([]) do
    # Logger.debug("initialize memeory server")

    state = %{
      # Обыкновенный стек
      stack: [],
      # Регистры для пользовательских переменных
      memory: %{},
      functions: %{},
      # Константы
      consts: %{
        'PI' => 3.14159265358979323846,
        "PI" => 3.14159265358979323846,
        'E' => 2.71828182845904523536,
        "E" => 2.71828182845904523536,
        # постоянная Эйлера
        'GAMMA' => 0.57721566490153286060,
        "GAMMA" => 0.57721566490153286060,
        # градусов/радиан
        'DEG' => 57.29577951308232087680,
        "DEG" => 57.29577951308232087680,
        # золотое отношение
        'PHI' => 1.61803398874989484820,
        "PHI" => 1.61803398874989484820
      },
      # Встроенные функции
      builtins: %{
        'sin' => {:math, :sin},
        "sin" => {:math, :sin},
        'cos' => {:math, :cos},
        "cos" => {:math, :cos},
        # "atan"  => :atan,
        # "log"   => Log,    # проверка аргумента
        # "log10" => Log10, # проверка аргумента
        # проверка аргумента
        'exp' => {:math, :exp},
        "exp" => {:math, :exp},
        #  проверка аргумента
        'sqrt' => {:math, :sqrt},
        "sqrt" => {:math, :sqrt},
        # "int"   => integer,
        # erlang:abs(-3)
        'abs' => {:erlang, :abs},
        "abs" => {:erlang, :abs},
        'pow' => {:math, :pow},
        "pow" => {:math, :pow}
      }
    }

    {:ok, state}
  end

  # CALL

  @impl true
  def handle_call(:pop, _from, %{:stack => stack} = state) do
    # Logger.debug("pop element from stack")
    [head | tail] = stack
    {:reply, head, %{state | stack: tail}}
  end

  def handle_call(:shift, _from, %{:stack => stack} = state) do
    # Logger.debug("shift element from stack")
    {head, tail} = Enum.split(stack, length(stack) - 1)
    {:reply, tail, %{state | stack: head}}
  end

  def handle_call(:dump, _from, %{:stack => stack} = state) do
    # Logger.debug("dump stack")
    # {:reply, stack, %{state | stack: stack}}
    {:reply, stack, %{state | stack: []}}
  end

  def handle_call({:get, key}, _from, %{:memory => memory} = state) do
    # Logger.debug("get element from memory")
    result = Map.get(memory, key, :undefined)
    {:reply, result, state}
  end

  def handle_call({:call, function}, _from, %{:functions => functions} = state) do
    # Logger.debug("call function #{function}")
    result = Map.get(functions, function, :undefined)
    {:reply, result, state}
  end

  def handle_call({:get_const, key}, _from, %{:consts => consts} = state) do
    # Logger.debug("get const from table")
    result = Map.get(consts, key, 0)
    {:reply, result, state}
  end

  def handle_call({:get_builtin, key}, _from, %{:builtins => builtins} = state) do
    # Logger.debug("get builtin from table")
    result = Map.get(builtins, key, :undefined)
    {:reply, result, state}
  end

  def handle_call({:is_constant, key}, _from, %{:consts => consts} = state) do
    # Logger.debug("is_constant test for #{inspect(key)}")
    result = Map.has_key?(consts, key)
    {:reply, result, state}
  end

  def handle_call({:is_builtin, key}, _from, %{:builtins => builtins} = state) do
    # Logger.debug("is_builtin test for #{inspect(key)}")
    result = Map.has_key?(builtins, key)
    {:reply, result, state}
  end

  def handle_call({:is_function, key}, _from, %{:functions => functions} = state) do
    # Logger.debug("is_function test for #{inspect(key)}")
    result = Map.has_key?(functions, key)
    {:reply, result, state}
  end

  def handle_call(:get_functions, _from, %{:functions => functions} = state) do
    # Logger.debug("get functions table")
    {:reply, functions, state}
  end

  # def handle_call({:push, element}, _from, %{:stack => stack} = state) do
  #   Logger.debug("push element into stack")
  #   stack = [element | stack]
  #   {:reply, length(stack), %{state | stack: stack }}
  # end

  def handle_call({:unshift, element}, _from, %{:stack => stack} = state) do
    # Logger.debug("unshift element into stack")
    position = length(stack)
    stack = List.insert_at(stack, position, element)
    {:reply, position + 1, %{state | stack: stack}}
  end

  def handle_call(:get_depth, _from, %{:stack => stack} = state) do
    # Logger.debug("get stack depth")
    depth = length(stack)
    {:reply, depth, %{state | stack: stack}}
  end

  def handle_call(message, _from, state) do
    Logger.debug("Undefined CALL message #{inspect(message)}")
    {:noreply, state}
  end

  # CAST

  @impl true
  def handle_cast({:push, element}, %{:stack => stack} = state) do
    # Logger.debug("push element into stack")
    {:noreply, %{state | stack: [element | stack]}}
  end

  def handle_cast({:roll_up, position}, %{:stack => stack} = state) do
    # Logger.debug("roll up stack from end to #{inspect(position)}")
    {prog, sub} = Enum.split(stack, position)
    position = length(stack)
    stack = List.insert_at(prog, position, sub)
    {:noreply, %{state | stack: stack}}
  end

  # def handle_cast({:unshift, element}, %{:stack => stack} = state) do
  #   Logger.debug("unshift element into stack")
  #   stack = List.insert_at(stack, length(stack), element)
  #   {:noreply, %{state | stack: stack}}
  # end

  def handle_cast({:insert, position, element}, %{:stack => stack} = state) do
    # Logger.debug("insert element in stack on exact position")
    {left, right} = Enum.split(stack, position)
    stack = Enum.concat(left, [element | right])
    {:noreply, %{state | stack: stack}}
  end

  def handle_cast(:nested, %{:stack => stack} = state) do
    # Logger.debug("nested stack")
    stack = [stack]
    {:noreply, %{state | stack: stack}}
  end

  def handle_cast(:embed_nested, %{:stack => stack} = state) do
    # Logger.debug("embed nested stack into main stack")
    [head | tail] = stack
    stack = List.insert_at(head, length(head), tail)
    {:noreply, %{state | stack: stack}}
  end

  def handle_cast(
        :place_function,
        %{
          :stack => stack,
          :functions => functions
        } = state
      ) do
    # Logger.debug("place a function into fucntion table")
    # Logger.debug(" ==[ROUTINE]== #{inspect(stack)}")
    position = length(stack) - 1
    {head, [[:routine | routine]] = _tail} = Enum.split(stack, position)

    # если уж перебор делать, и арность можно здесь же считать
    code = []
    args = []
    arity = 0
    function = ""

    # состояние разбора либо декларация функции либо её тело
    state2 = :decl

    # res =
    {function, arity, args, code, _state2} =
      Enum.reduce(routine, {function, arity, args, code, state2}, fn
        :body, {_function, arity, args, [function] = _code, :decl = _state2} ->
          {function, arity, args, [], :body}

        :var, {function, arity, args, [var | code], :decl = state2} ->
          {function, arity + 1, [var | args], code, state2}

        x, {function, arity, args, code, state2} ->
          {function, arity, args, [x | code], state2}
      end)

    # res = %{name: function, args: args, arity: arity, code: Enum.reverse(code)}

    # Logger.debug(
    #   " ==[ROUTINE]== res -> #{inspect(res)} is binary #{is_binary(res.name)} is list #{
    #     is_list(res.name)
    #   }"
    # )

    functions =
      Map.put(functions, function, %{args: args, arity: arity, code: Enum.reverse(code)})

    stack = head
    {:noreply, %{state | stack: stack, functions: functions}}
  end

  def handle_cast(:stop, State) do
    # Logger.debug("memory server has stopped")
    {:stop, :normal, State}
  end

  def handle_cast({:put, key, value}, %{:memory => memory} = state) do
    # Logger.debug("put element into memory")
    memory = Map.put(memory, key, value)
    {:noreply, %{state | memory: memory}}
  end

  def handle_cast(message, state) do
    Logger.debug("Undefined CAST message #{inspect(message)}")
    {:noreply, state}
  end
end

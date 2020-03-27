defmodule Acx.Matcher do
  @enforce_keys [:prog]
  defstruct prog: nil

  alias __MODULE__

  alias Acx.Helpers
  alias Acx.Parser
  alias Acx.Operator

  @unary_operators [:not, :pos, :neg]
  @binary_operators [:mul, :div, :add, :sub, :lt, :le, :gt, :ge, :eq,
                     :ne, :and, :or]

  # Convert a matcher string to a matcher program.
  # ##############################################

  # Instruction type.
  @type instr() :: {:push, number()}
  | {:push, String.t()}
  | {:fetch, atom()}
  | {:fetch_attr, %{key: atom(), attr: atom()}}
  | {:not}
  | {:pos}
  | {:neg}
  | {:mul}
  | {:div}
  | {:add}
  | {:sub}
  | {:lt}
  | {:le}
  | {:gt}
  | {:ge}
  | {:eq}
  | {:ne}
  | {:and}
  | {:or}
  | {:call, %{name: atom(), arity: non_neg_integer()}}

  # Matcher program type.
  @type program() :: [instr()]

  @doc """
  Converts the given matcher string `str` to a matcher program.
  """
  @spec new(String.t()) :: {:ok, program()} | {:error, {atom(), map()}}
  def new(str) do
    str
    |> Parser.parse()
    |> convert_from_postfix()
    |> case do
         {:error, reason} ->
           {:error, reason}

         {:ok, postfix} ->
           prog = postfix |> compile()
           {:ok, %Matcher{prog: prog}}
       end
  end

  @doc """
  Runs a matcher program in the given environment
  """

  @type environment() :: map()
  @type result() :: number() | String.t() | boolean()

  @spec eval(%Matcher{}, environment()) :: result()
  def eval(%Matcher{prog: prog}, env \\ %{}) do
    run(prog, env)
  end

  def eval!(%Matcher{} = m, env \\ %{}) do
    case eval(m, env) do
      {:error, reason} ->
        raise RuntimeError, message: reason

      {:ok, result} ->
        result
    end
  end

  # Compile a matcher expression to a program
  # #########################################

  # Matcher expression
  @type t :: {:num, number()}
  | {:str, String.t()}
  | {:var, atom()}
  | {:dot, atom(), atom()}
  | {:not, t()}
  | {:pos, t()}
  | {:neg, t()}
  | {:mul, t(), t()}
  | {:div, t(), t()}
  | {:add, t(), t()}
  | {:sub, t(), t()}
  | {:lt, t(), t()}
  | {:le, t(), t()}
  | {:gt, t(), t()}
  | {:ge, t(), t()}
  | {:eq, t(), t()}
  | {:ne, t(), t()}
  | {:and, t(), t()}
  | {:or, t(), t()}
  | {:call, atom(), [t()]}

  @spec compile(t()) :: program()
  defp compile({:num, x}), do: [{:push, x}]
  defp compile({:str, s}), do: [{:push, s}]
  defp compile({:dot, k, attr}), do: [{:fetch_attr, %{key: k, attr: attr}}]
  defp compile({:var, v}), do: [{:fetch, v}]
  defp compile({:not, e}), do: compile(e) ++ [{:not}]
  defp compile({:pos, e}), do: compile(e) ++ [{:pos}]
  defp compile({:neg, e}), do: compile(e) ++ [{:neg}]
  defp compile({:mul, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:mul}]
  defp compile({:div, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:div}]
  defp compile({:add, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:add}]
  defp compile({:sub, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:sub}]
  defp compile({:lt, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:lt}]
  defp compile({:le, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:le}]
  defp compile({:gt, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:gt}]
  defp compile({:ge, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:ge}]
  defp compile({:eq, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:eq}]
  defp compile({:ne, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:ne}]
  defp compile({:and, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:and}]
  defp compile({:or, e1, e2}), do: compile(e1) ++ compile(e2) ++ [{:or}]
  defp compile({:call, name, args}) do
    ins = Enum.reduce(args, [], fn e, acc ->
      acc ++ compile(e)
    end)
    ins ++ [{:call, %{name: name, arity: length(args)}}]
  end

  # Run a matcher program in the given environment.
  # ###############################################

  @type virtual_machine() :: [result()]

  @spec run(program(), environment()) :: result()
  defp run(pro, env), do: run(pro, env, [])

  @spec run(program(), environment(), virtual_machine()) :: result()

  defp run([{:push, x} | continue], env, stack) do
    run(continue, env, [x | stack])
  end

  defp run([{:fetch, a} | continue], env, stack) do
    case lookup(a, env) do
      {:error, :not_found} ->
        {:error, "undefined variable #{a}"}

      {:ok, value} ->
        run(continue, env, [value | stack])
    end
  end

  defp run([{:fetch_attr, %{key: k, attr: a}} | continue], env, stack) do
    case lookup_attr(%{key: k, attr: a}, env) do
      {:error, :key_not_found} ->
        {:error, "undefined variable #{k}"}

      {:error, :attribute_not_found} ->
        {:error, "undefined attribute #{a} for variable #{k}"}

      {:ok, value} ->
        run(continue, env, [value | stack])
    end
  end

  defp run([{op} | continue], env, [head | tail])
  when op in @unary_operators do
    case Operator.apply(op, [head]) do
      {:error, reason} ->
        {:error, reason}

      {:ok, value} ->
        run(continue, env, [value | tail])
    end
  end

  defp run([{op} | continue], env, [rhs, lhs | tail])
  when op in @binary_operators do
    case Operator.apply(op, [lhs, rhs]) do
      {:error, reason} ->
        {:error, reason}

      {:ok, value} ->
        run(continue, env, [value | tail])
    end
  end

  defp run([{:call, fun} | continue], env, stack) do
    %{name: name, arity: arity} = fun
    case lookup_function(fun, env) do
      {:error, :not_found} ->
        {:error, "undefined function #{name}/#{arity}"}

      {:ok, f} ->
        {:ok, args, rem} = Helpers.pop_stack(stack, arity)
        value = apply(f, args)
        run(continue, env, [value | rem])
    end
  end

  defp run([], _env, [result]), do: {:ok, result}


  # Convert from a postfix expression to a matcher expression.
  # #########################################################

  defp convert_from_postfix({:ok, postfix}) do
    convert_from_postfix(postfix, [])
  end

  defp convert_from_postfix({:error, reason}) do
    {:error, reason}
  end

  #
  # We reach the end of the input postfix expression.
  #

  # One item on the stack?
  defp convert_from_postfix([], [expr]), do: {:ok, expr}

  # Zero or two more items?
  # TODO: error at what position?
  defp convert_from_postfix([], _), do: {:error, :syntax_error}

  #
  # Operand
  #

  # Number
  defp convert_from_postfix([%{token: {:num, x}} | rest], stack) do
    convert_from_postfix(rest, [{:num, x} | stack])
  end

  # String
  defp convert_from_postfix([%{token: {:str, s}} | rest], stack) do
    convert_from_postfix(rest, [{:str, s} | stack])
  end

  # variable
  defp convert_from_postfix([%{token: {:var, v}} | rest], stack) do
    convert_from_postfix(rest, [{:var, v} | stack])
  end

  #
  # :dot
  #

  defp convert_from_postfix(
    [%{token: :dot} | rest],
    [{:var, attr}, {:var, key} | stack]
  ) do
    convert_from_postfix(rest, [{:dot, key, attr} | stack])
  end

  # For anything else, we consider it's a syntax error.
  defp convert_from_postfix([%{token: :dot} = token | _], _) do
    syntax_error(token)
  end

  #
  # Unary operator.
  #

  defp convert_from_postfix([%{token: op} | rest], [head | tail])
  when op in @unary_operators do
    convert_from_postfix(rest, [{op, head} | tail])
  end

  defp convert_from_postfix([%{token: op} = token | _], [])
  when op in @unary_operators do
    syntax_error(token)
  end

  #
  # Binary operator.
  #

  defp convert_from_postfix([%{token: op} | rest], [rhs, lhs | tail])
  when op in @binary_operators do
    convert_from_postfix(rest, [{op, lhs, rhs} | tail])
  end

  defp convert_from_postfix([%{token: op} = token | _], _) when
  op in @binary_operators do
    syntax_error(token)
  end

  #
  # Function.
  #

  defp convert_from_postfix([%{token: {:fun, fun}} = t | rest], stack) do
    %{name: name, arity: arity} = fun
    case Helpers.pop_stack(stack, arity) do
      {:error, _} ->
        # There was a discrepancy between function arity and the number
        # of arguments provided
        syntax_error(t)

      {:ok, succeeds, rem} ->
        convert_from_postfix(rest, [{:call, name, succeeds} | rem])
    end
  end

  # Helpers
  # ######

  # Dot syntax error.
  defp syntax_error(%{token: :dot} = arg) do
    {:error, {:syntax_error, %{arg | token: '.'}}}
  end

  # Operator syntax error.
  defp syntax_error(%{token: op} = arg)
  when op in @unary_operators or op in @binary_operators do
    {
      :error,
      {:syntax_error, %{arg | token: Operator.operator_to_charlist(op)}}
    }
  end

  # Function syntax error.
  defp syntax_error(%{token: {:fun, %{name: name}}} = arg) do
    {
      :error,
      {:syntax_error, %{arg | token: :erlang.atom_to_list(name)}}
    }
  end


  # Lookup variable name `v` in the given environment `env`.
  defp lookup(v, env) do
    case Map.get(env, v) do
      nil ->
        {:error, :not_found}

      value ->
        {:ok, value}
    end
  end

  # Lookup the attribute named `a` for key `k`.
  defp lookup_attr(%{key: k, attr: a}, env) do
    case Map.get(env, k) do
      nil ->
        {:error, :key_not_found}

      attrs ->
        case attrs[a] do
          nil ->
            {:error, :attribute_not_found}

          value ->
            {:ok, value}
        end
    end
  end

  # Lookup function
  defp lookup_function(%{name: name, arity: arity}, env) do
    case Map.get(env, name) do
      nil ->
        {:error, :not_found}

      f when not is_function(f, arity) ->
        {:error, :not_found}

      f ->
        {:ok, f}
    end
  end

end

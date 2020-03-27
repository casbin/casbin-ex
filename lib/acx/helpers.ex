defmodule Acx.Helpers do

  @doc """
  Returns a tuple `{succeeds, remainder}` where `succeeds` is the initial
  segment of the given `list`, in which all elements have the property `p`,
  and `remainder` is the remainder of the `list`.

  If `reverse` is set to `true` the `succeeds` list will be reversed
  (default).
  """
  def get_while(p, list, reverse \\ true) do
    {succeeds, remainder, count} = get_while_reverse(p, list, [], 0)
    case reverse do
      true ->
        {succeeds, remainder, count}

      false ->
        {Enum.reverse(succeeds), remainder, count}
    end
  end

  defp get_while_reverse(p, [head | tail], ret, count) do
    case p.(head) do
      false ->
        {ret, [head | tail], count}

      true ->
        get_while_reverse(p, tail, [head | ret], count + 1)
    end
  end

  defp get_while_reverse(_p, [], ret, count) do
    {ret, [], count}
  end

  @doc """
  Pops `n` number of items from the given stack.
  """
  def pop_stack(stack, n) do
    pop_stack(stack, [], n)
  end

  defp pop_stack(rem, succeeds, 0), do: {:ok, succeeds, rem}

  defp pop_stack([], _, _), do: {:error, :not_enough_arguments}

  defp pop_stack([head | tail], succeeds, n) do
    pop_stack(tail, [head | succeeds], n - 1)
  end

  @doc """
  Returns `true` if the given keyword list has duplicate keys in it,
  `false` otherwise.
  """
  def has_duplicate_key?(list) do
    keys = Keyword.keys(list)
    length(keys) != length(Enum.uniq(keys))
  end

end

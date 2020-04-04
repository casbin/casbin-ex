defmodule Acx.Internal.PartialRangeFrom do
  @moduledoc """
  PartialRangeFrom represents a partial interval extending upward from
  a lower bound `[lower_bound, infinity)`.
  """

  defstruct lower_bound: nil

  @type value() :: integer() | float()
  @type t :: %__MODULE__{lower_bound: value()}
  @type t(lower_bound) :: %__MODULE__{lower_bound: lower_bound}

  @doc """
  Creates a new partial range from the given lower bound.

  ## Examples

      iex> at_least_five = PartialRangeFrom.new(5)
      ...> false = at_least_five |> PartialRangeFrom.contains?(4)
      ...> true = at_least_five |> PartialRangeFrom.contains?(5)
      ...> at_least_five |> PartialRangeFrom.contains?(6)
      true
  """
  @spec new(value()) :: t()
  def new(lower_bound) when is_integer(lower_bound) or
  is_float(lower_bound) do
    %__MODULE__{lower_bound: lower_bound}
  end

  def new(lower_bound) do
    raise ArgumentError,
      "partial range from [lower_bound...) expects `lower_bound` to be " <>
      "an integer or a float, got: #{inspect lower_bound}"
  end

  @doc """
  Returns `true` if `value` is contained in the given range.

  Returns `false`, otherwise.

  ## Examples

      iex> range = PartialRangeFrom.new(1.5)
      ...> range |> PartialRangeFrom.contains?(1.5)
      true

      iex> range = PartialRangeFrom.new(1.5)
      ...> range |> PartialRangeFrom.contains?(1.6)
      true

      iex> range = PartialRangeFrom.new(1.5)
      ...> range |> PartialRangeFrom.contains?(5)
      true

      iex> range = PartialRangeFrom.new(1.5)
      ...> range |> PartialRangeFrom.contains?(1.4)
      false

      iex> range = PartialRangeFrom.new(1.5)
      ...> range |> PartialRangeFrom.contains?(0)
      false
  """
  @spec contains?(t(), value()) :: boolean()
  def contains?(%__MODULE__{lower_bound: lower_bound}, val)
  when is_integer(val) or is_float(val) do
    val >= lower_bound
  end

  def contains?(%__MODULE__{}, _), do: false

  @doc """
  Converts a string representation of a partial range to
  the `PartialRangefrom` struct.

  A valid string representation must be of the form: "lower_bound..."
  in which `lower_bound` must be a number (integer or float).

  ## Examples

      iex> {:ok, range} = PartialRangeFrom.compile("5...")
      ...> range
      %PartialRangeFrom{lower_bound: 5}

      iex> {:ok, range} = PartialRangeFrom.compile("1.5...")
      ...> range
      %PartialRangeFrom{lower_bound: 1.5}

      iex> {:ok, range} = PartialRangeFrom.compile("-1.5...")
      ...> range
      %PartialRangeFrom{lower_bound: -1.5}

      iex> {:error, reason} = PartialRangeFrom.compile("5..")
      ...> reason
      "invalid string representation"

      iex> {:error, reason} = PartialRangeFrom.compile("a..")
      ...> reason
      "invalid string representation"
  """
  @spec compile(String.t()) :: {:ok, t()} | {:error, String.t()}
  def compile(str) do
    case parse(str) do
      nil ->
        {:error, "invalid string representation"}

      num ->
        {:ok, new(num)}
    end
  end

  @pattern ~r/^(?<number>[+,-]?\d+((?<has_dot>\.)\d+)?)\.{3}$/
  defp parse(str) do
    case Regex.named_captures(@pattern, str) do
      %{"number" => value, "has_dot" => ""} ->
        {i, ""} = Integer.parse(value)
        i

      %{"number" => value, "has_dot" => "."} ->
        {f, ""} = Float.parse(value)
        f

      _ ->
        nil
    end
  end

end

defmodule Acx.PolicyEffect do
  @moduledoc """
  Policy effect defines whether the access should be approved or denied
  if multiple policy rules match the request.

  For now, only the following policy effect rules are valid:

  1. `"some(where(p.eft==allow))"`: if there's any matched policy rule of
    type `allow`, the final effect is `allow`. Which means if there's no
    match or all matches are of type `deny`, the final effect is `deny`.

  2. `"!some(where(p.eft==deny))"`: if there's no matched policy rules of
    type `deny`, the final effect is `allow`.
  """

  defstruct rule: nil

  alias __MODULE__
  alias Acx.Policy

  @allow_override "some(where(p.eft==allow))"
  @deny_override "!some(where(p.eft==deny))"

  @doc """
  Create a new policy effect based on the given `rule` string.

  ## Examples

     iex> Acx.PolicyEffect.new("some(where(p.eft==allow))")
     %Acx.PolicyEffect{rule: "some(where(p.eft==allow))"}

     iex> Acx.PolicyEffect.new("!some(where(p.eft==deny))")
     %Acx.PolicyEffect{rule: "!some(where(p.eft==deny))"}
  """
  def new(rule) when rule in [@allow_override, @deny_override] do
    %PolicyEffect{rule: rule}
  end

  @doc """
  Returns `true` if there's at least one policy rule of type `allow`
  in the given `matched_policies` list.

  Returns `false`, otherwise.
  """
  def reduce(matched_policies, %PolicyEffect{rule: @allow_override}) do
    Enum.any?(matched_policies, &Policy.allow?/1)
  end

  @doc """
  Returns `true` iff there's no policies of type `deny` in the given
  `matched_policies` list.

  Returns `false` otherwise.
  """
  def reduce(matched_policies, %PolicyEffect{rule: @deny_override}) do
    Enum.all?(matched_policies, &Policy.allow?/1)
  end

end

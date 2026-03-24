defmodule RaffleEngine.Hash do
  def sha256(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  def to_integer(hex) do
    {int, _} = Integer.parse(hex, 16)
    int
  end
end

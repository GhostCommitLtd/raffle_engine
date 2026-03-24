defmodule RaffleEngine.Normalizer do
  def normalize_seed(seed) when is_integer(seed) do
    Integer.to_string(seed)
  end

  def normalize_seed(seed) when is_binary(seed) do
    String.trim(seed)
  end

  def normalize_seed(seed) do
    seed
    |> to_string()
    |> String.trim()
  end
end

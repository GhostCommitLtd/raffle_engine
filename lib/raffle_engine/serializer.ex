defmodule RaffleEngine.Serializer do
  @spec serialize([String.t()], String.t()) :: iodata()
  def serialize(participants, "1.0.0") do
    Enum.join(participants, ",")
  end

  def serialize(participants, "1.0.1") do
    # Unambiguous, stable encoding: each entry is length-prefixed.
    # Example: "5:alice\n3:bob\n"
    participants
    |> Enum.map(fn p ->
      [Integer.to_string(byte_size(p)), ":", p, "\n"]
    end)
  end

  def serialize(participants, "1.0.2"), do: serialize(participants, "1.0.1")

  def serialize(participants, version) when is_list(participants) do
    raise ArgumentError, "unsupported serialization version: #{inspect(version)}"
  end
end

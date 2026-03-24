defmodule RaffleEngine.CLI do
  def main(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [participants: :string, seed: :string]
      )

    participants_arg = opts[:participants]
    seed = opts[:seed]

    if is_nil(participants_arg) or is_nil(seed) do
      IO.puts(:stderr, "Usage: raffle_engine --participants \"a,b,c\" --seed \"some-seed\"")
      System.halt(1)
    end

    participants = String.split(participants_arg, ",")

    case RaffleEngine.pick_winner_safe(participants, seed) do
      {:ok, draw} ->
        IO.inspect(draw.winners)

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(2)
    end
  end
end

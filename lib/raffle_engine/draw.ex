defmodule RaffleEngine.Draw do
  @enforce_keys [
    :participants,
    :participants_hash,
    :seed,
    :normalized_seed,
    :winners,
    :indexes,
    :algorithm_version
  ]

  @type t :: %__MODULE__{
          participants: [String.t()],
          participants_hash: String.t(),
          seed: term(),
          normalized_seed: String.t(),
          winners: [String.t()],
          indexes: [non_neg_integer()],
          algorithm_version: String.t()
        }

  defstruct @enforce_keys
end

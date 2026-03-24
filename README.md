# RaffleEngine

Deterministic, verifiable winner selection for giveaways/raffles.

RaffleEngine is **not** a live RNG. It produces a reproducible result from:

- a participant "ticket" list (duplicates allowed), and
- a seed.

Anyone who has the same inputs can reproduce the same winners and verify the stored proof.

## Installation

### As a git dependency

In your `mix.exs`:

```elixir
defp deps do
  [
    {:raffle_engine, git: "<REPO_URL>", tag: "v0.3.0"}
  ]
end
```

Then:

```bash
mix deps.get
```

## Basic usage

Pick one winner:

```elixir
participants = ["alice", "bob", "charlie"]
seed = "my-seed"

draw = RaffleEngine.pick_winner(participants, seed)
# draw.winners => ["..."]
# draw.participants_hash => "..."

RaffleEngine.verify(draw)
#=> true
```

Pick multiple winners:

```elixir
participants = ["alice", "bob", "charlie", "dana"]
seed = "my-seed"

draw = RaffleEngine.pick_n_winners(participants, seed, 2)
# draw.winners => ["...", "..."]
```

Use safe APIs (recommended for web/API usage):

```elixir
case RaffleEngine.pick_n_winners_safe(participants, seed, 2) do
  {:ok, draw} -> draw
  {:error, reason} -> reason
end
```

## Tickets, duplicates, and weighted entries

RaffleEngine treats the participant list as **tickets**:

- If the same label appears twice, it counts as two entries.

Example (explicit duplicates):

```elixir
participants = ["alice", "alice", "bob"]
RaffleEngine.pick_winner(participants, "seed")
```

You can also provide weights instead of repeating labels.

### Weighted list (tuples / keyword pairs)

Valid examples:

```elixir
# tuples
participants = [{"alice", 2}, "bob", {"charlie", 5}]

# keyword pairs must come last in a list
participants = ["bob", alice: 2, charlie: 5]
```

### Weighted map

```elixir
participants = %{"alice" => 2, "bob" => 1, "charlie" => 5}
```

All weighted forms are expanded into tickets internally.

## Algorithm versioning

The returned `draw` includes `algorithm_version` so historical draws can remain verifiable if the implementation evolves.

- `1.0.0`: legacy behavior (minimal normalization)
- `1.0.1`: trims participant strings and uses unambiguous participant hashing
- `1.0.2` (default): supports duplicate tickets deterministically and order-independently

You can pin a version:

```elixir
{:ok, draw} = RaffleEngine.pick_winner_safe(participants, seed, algorithm_version: "1.0.0")
```

## CLI

This project builds an escript (main module `RaffleEngine.CLI`). The current CLI accepts a comma-separated list:

```bash
mix escript.build
./raffle_engine --participants "alice,bob,charlie" --seed "my-seed"
```

(For weighted inputs, prefer the library API from your Phoenix app.)

## Testing and formatting

```bash
mix test
mix format
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Production guidance (seed governance)

If you need transparency (users can verify/reproduce later), you must define how the seed is chosen.

See [INTEGRATION.md](INTEGRATION.md) for a recommended production workflow (hybrid seed using drand + commit–reveal + deferred draw/retry).

## License

MIT. See [LICENSE](LICENSE).

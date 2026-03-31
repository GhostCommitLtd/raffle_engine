defmodule RaffleEngineTest do
  use ExUnit.Case

  test "deterministic winner" do
    participants = ["alice", "bob", "charlie"]
    seed = "test-seed"

    draw1 = RaffleEngine.pick_winner(participants, seed)
    draw2 = RaffleEngine.pick_winner(participants, seed)

    assert draw1.winners == draw2.winners
  end

  test "verify works" do
    participants = ["a", "b", "c"]
    seed = "123"

    draw = RaffleEngine.pick_winner(participants, seed)

    assert RaffleEngine.verify(draw)
  end

  test "duplicate entries count as multiple tickets (v1.0.2)" do
    participants = ["alice", "alice", "bob"]
    seed = "seed"

    {:ok, draw1} = RaffleEngine.pick_n_winners_safe(participants, seed, 2)
    {:ok, draw2} = RaffleEngine.pick_n_winners_safe(participants, seed, 2)

    assert draw1.winners == draw2.winners
    assert length(draw1.participants) == 3
    assert RaffleEngine.verify(draw1)
  end

  test "weighted entries via keyword/list syntax" do
    weighted = ["bob", alice: 2, charlie: 5]
    expanded = ["alice", "alice", "bob"] ++ List.duplicate("charlie", 5)
    seed = "seed"

    {:ok, draw_weighted} = RaffleEngine.pick_n_winners_safe(weighted, seed, 3)
    {:ok, draw_expanded} = RaffleEngine.pick_n_winners_safe(expanded, seed, 3)

    assert draw_weighted.winners == draw_expanded.winners
    assert RaffleEngine.verify(draw_weighted)
  end

  test "ordered weighted arrays and objects are accepted without caller adaptation" do
    weighted = ["bob", ["alice", 2], %{"label" => "charlie", "count" => 2}]

    {:ok, draw} = RaffleEngine.pick_n_winners_safe(weighted, "seed", 2)

    assert draw.original_participants == ["bob", "alice", "alice", "charlie", "charlie"]
    assert draw.participants == ["alice", "alice", "bob", "charlie", "charlie"]
    assert RaffleEngine.verify(draw)
  end

  test "prepare_participants_safe returns canonical participants and hash" do
    input = [["alice", 2], "bob"]

    {:ok, prepared} = RaffleEngine.prepare_participants_safe(input)
    {:ok, draw} = RaffleEngine.pick_winner_safe(input, "seed")

    assert prepared.original_participants == ["alice", "alice", "bob"]
    assert prepared.participants == draw.participants
    assert prepared.participants_hash == draw.participants_hash
    assert prepared.algorithm_version == draw.algorithm_version
  end

  test "top-level weighted maps are rejected" do
    assert {:error, :invalid_participants} =
             RaffleEngine.pick_winner_safe(%{"alice" => 2, "bob" => 1}, "seed")
  end

  test "invalid ordered weighted entries return errors instead of becoming labels" do
    assert {:error, {:invalid_entry_count, "2"}} =
             RaffleEngine.pick_winner_safe([["alice", "2"], "bob"], "seed")

    assert {:error, {:invalid_entry_count, 0}} =
             RaffleEngine.pick_winner_safe([%{"label" => "alice", "count" => 0}, "bob"], "seed")
  end

  test "v1.0.1 trims and removes empty entries" do
    participants = [" alice ", " ", "bob"]
    seed = "seed"

    {:ok, draw} = RaffleEngine.pick_winner_safe(participants, seed)

    assert draw.participants == ["alice", "bob"]
    assert RaffleEngine.verify(draw)
  end

  test "verify detects tampering" do
    participants = ["a", "b", "c"]
    seed = "seed"

    draw = RaffleEngine.pick_n_winners(participants, seed, 2)

    refute RaffleEngine.verify(%{draw | participants_hash: "deadbeef"})
    refute RaffleEngine.verify(%{draw | winners: Enum.reverse(draw.winners)})
  end

  test "legacy algorithm version is still verifiable" do
    participants = [" alice ", "bob", "charlie"]
    seed = "seed"

    {:ok, draw} =
      RaffleEngine.pick_winner_safe(participants, seed, algorithm_version: "1.0.0")

    assert draw.algorithm_version == "1.0.0"
    assert RaffleEngine.verify(draw)
  end
end

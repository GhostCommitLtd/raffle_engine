defmodule RaffleEngine do
  alias RaffleEngine.{Draw, Hash, Serializer, Normalizer}

  @current_algorithm_version "1.0.2"
  @supported_algorithm_versions ["1.0.0", "1.0.1", @current_algorithm_version]

  @type participant :: String.t()
  @type participants_input :: list()
  @type seed :: String.t() | integer()
  @type error_reason ::
          :missing_seed
          | :missing_participants
          | :invalid_participants
          | :invalid_draw
          | :invalid_winner_count
          | :invalid_entry_count
          | :unsupported_algorithm_version

  @spec prepare_participants(participants_input(), keyword()) ::
          %{
            original_participants: [String.t()],
            participants: [String.t()],
            participants_hash: String.t(),
            algorithm_version: String.t()
          }
  def prepare_participants(participants, opts \\ []) do
    case prepare_participants_safe(participants, opts) do
      {:ok, prepared} ->
        prepared

      {:error, reason} ->
        raise ArgumentError, "RaffleEngine.prepare_participants/2 failed: #{format_error(reason)}"
    end
  end

  @spec prepare_participants_safe(participants_input(), keyword()) ::
          {:ok,
           %{
             original_participants: [String.t()],
             participants: [String.t()],
             participants_hash: String.t(),
             algorithm_version: String.t()
           }}
          | {:error, error_reason() | {error_reason(), term()}}
  def prepare_participants_safe(participants, opts \\ []) do
    algorithm_version = Keyword.get(opts, :algorithm_version, @current_algorithm_version)

    with :ok <- validate_algorithm_version(algorithm_version),
         {:ok, expanded_participants} <- expand_participants_input(participants),
         {:ok, original_participants} <- normalize_original_participants(expanded_participants),
         {:ok, canonical_participants} <-
           canonicalize_participants(expanded_participants, algorithm_version) do
      {:ok,
       %{
         original_participants: original_participants,
         participants: canonical_participants,
         participants_hash: participants_hash(canonical_participants, algorithm_version),
         algorithm_version: algorithm_version
       }}
    end
  end

  def pick_winner(participants, seed, opts \\ []) do
    pick_n_winners(participants, seed, 1, opts)
  end

  @spec pick_winner_safe(participants_input(), seed(), keyword()) ::
          {:ok, Draw.t()} | {:error, error_reason() | {error_reason(), term()}}
  def pick_winner_safe(participants, seed, opts \\ []) do
    pick_n_winners_safe(participants, seed, 1, opts)
  end

  def pick_n_winners(participants, seed, n, opts \\ []) do
    case pick_n_winners_safe(participants, seed, n, opts) do
      {:ok, draw} ->
        draw

      {:error, reason} ->
        raise ArgumentError, "RaffleEngine.pick_n_winners/4 failed: #{format_error(reason)}"
    end
  end

  @spec pick_n_winners_safe(participants_input(), seed(), pos_integer(), keyword()) ::
          {:ok, Draw.t()} | {:error, error_reason() | {error_reason(), term()}}
  def pick_n_winners_safe(participants, seed, n, opts \\ []) do
    algorithm_version = Keyword.get(opts, :algorithm_version, @current_algorithm_version)

    with :ok <- validate_algorithm_version(algorithm_version),
         {:ok, normalized_seed} <- normalize_seed(seed),
         {:ok, expanded_participants} <- expand_participants_input(participants),
         {:ok, original_participants} <- normalize_original_participants(expanded_participants),
         {:ok, canonical_participants} <-
           canonicalize_participants(expanded_participants, algorithm_version),
         :ok <- validate_winner_count(n, canonical_participants) do
      participants_hash = participants_hash(canonical_participants, algorithm_version)

      {winners, indexes} =
        pick_from_shuffle(canonical_participants, normalized_seed, n, algorithm_version)

      {:ok,
       %Draw{
         original_participants: original_participants,
         participants: canonical_participants,
         participants_hash: participants_hash,
         seed: seed,
         normalized_seed: normalized_seed,
         winners: winners,
         indexes: indexes,
         algorithm_version: algorithm_version
       }}
    end
  end

  def shuffle(participants, seed) do
    participants
    |> Enum.map(fn p ->
      hash = Hash.sha256(seed <> p)
      {hash, p}
    end)
    |> Enum.sort_by(fn {hash, _} -> hash end)
    |> Enum.map(fn {_, p} -> p end)
  end

  def shuffle(participants, seed, algorithm_version) do
    participants
    |> shuffle_indexed(seed, algorithm_version)
    |> Enum.map(fn {_hash, _idx, p} -> p end)
  end

  def verify(draw) do
    case verify_safe(draw) do
      {:ok, true} -> true
      _ -> false
    end
  end

  @spec verify_safe(term()) ::
          {:ok, boolean()} | {:error, error_reason() | {error_reason(), term()}}
  def verify_safe(%Draw{} = draw) do
    with :ok <- validate_algorithm_version(draw.algorithm_version),
         :ok <- validate_winner_count(length(draw.winners), draw.participants) do
      recomputed_hash = participants_hash(draw.participants, draw.algorithm_version)

      {recomputed_winners, recomputed_indexes} =
        pick_from_shuffle(
          draw.participants,
          draw.normalized_seed,
          length(draw.winners),
          draw.algorithm_version
        )

      ok? =
        recomputed_hash == draw.participants_hash and
          recomputed_winners == draw.winners and
          recomputed_indexes == draw.indexes

      {:ok, ok?}
    end
  end

  def verify_safe(_), do: {:error, :invalid_draw}

  def replay(participants, seed, opts \\ []) do
    pick_winner(participants, seed, opts)
  end

  defp expand_participants_input(nil), do: {:error, :missing_participants}

  defp expand_participants_input(participants) when is_list(participants) do
    expanded =
      Enum.reduce_while(participants, [], fn
        entry, acc ->
          case expand_ordered_entry(entry) do
            {:ok, entries} -> {:cont, [entries | acc]}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end)

    case expanded do
      {:error, _} = error ->
        error

      list when is_list(list) ->
        expanded = list |> List.flatten() |> Enum.reverse()

        if expanded == [] do
          {:error, :missing_participants}
        else
          {:ok, expanded}
        end
    end
  end

  defp expand_participants_input(participants) when is_map(participants),
    do: {:error, :invalid_participants}

  defp expand_participants_input(_), do: {:error, :invalid_participants}

  defp expand_ordered_entry({key, count}) do
    with {:ok, count} <- normalize_count(count) do
      {:ok, List.duplicate(to_string(key), count)}
    end
  end

  defp expand_ordered_entry([label, count] = entry) do
    if List.ascii_printable?(entry) do
      {:ok, [to_string(entry)]}
    else
      with {:ok, count} <- normalize_count(count) do
        {:ok, List.duplicate(to_string(label), count)}
      end
    end
  end

  defp expand_ordered_entry(entry) when is_list(entry), do: {:error, :invalid_participants}

  defp expand_ordered_entry(%{} = entry) do
    with {:ok, label} <- fetch_weighted_label(entry),
         {:ok, count} <- fetch_weighted_count(entry) do
      {:ok, List.duplicate(label, count)}
    else
      :error -> {:error, :invalid_participants}
      {:error, _} = error -> error
    end
  end

  defp expand_ordered_entry(entry), do: {:ok, [to_string(entry)]}

  defp normalize_count(count) when is_integer(count) and count > 0, do: {:ok, count}
  defp normalize_count(count), do: {:error, {:invalid_entry_count, count}}

  defp normalize_original_participants(participants) when is_list(participants) do
    original_participants =
      participants
      |> Enum.map(fn participant ->
        participant
        |> to_string()
        |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))

    if original_participants == [] do
      {:error, :missing_participants}
    else
      {:ok, original_participants}
    end
  end

  defp fetch_weighted_label(entry) when is_map(entry) do
    case Map.fetch(entry, "label") do
      {:ok, value} -> {:ok, to_string(value)}
      :error -> fetch_atom_key(entry, :label)
    end
  end

  defp fetch_weighted_count(entry) when is_map(entry) do
    case Map.fetch(entry, "count") do
      {:ok, value} -> normalize_count(value)
      :error -> fetch_atom_count(entry)
    end
  end

  defp fetch_atom_key(entry, key) do
    if Map.has_key?(entry, key) do
      {:ok, entry |> Map.fetch!(key) |> to_string()}
    else
      :error
    end
  end

  defp fetch_atom_count(entry) do
    if Map.has_key?(entry, :count) do
      entry |> Map.fetch!(:count) |> normalize_count()
    else
      :error
    end
  end

  defp canonicalize_participants(participants, "1.0.0") when is_list(participants) do
    canonical = participants |> Enum.map(&to_string/1) |> Enum.sort()
    {:ok, canonical}
  end

  defp canonicalize_participants(participants, "1.0.1") when is_list(participants) do
    canonical =
      participants
      |> Enum.map(fn p ->
        p
        |> to_string()
        |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.sort()

    {:ok, canonical}
  end

  defp canonicalize_participants(participants, "1.0.2") when is_list(participants) do
    normalized =
      participants
      |> Enum.map(fn p ->
        p
        |> to_string()
        |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))

    # Deterministic multiset canonicalization that does not depend on input order.
    frequencies = Enum.frequencies(normalized)

    canonical =
      frequencies
      |> Enum.sort_by(fn {p, _count} -> p end)
      |> Enum.flat_map(fn {p, count} -> List.duplicate(p, count) end)

    {:ok, canonical}
  end

  defp canonicalize_participants(participants, _version) when not is_list(participants),
    do: {:error, :invalid_participants}

  defp canonicalize_participants(_participants, _version), do: {:error, :missing_participants}

  defp normalize_seed(nil), do: {:error, :missing_seed}
  defp normalize_seed(seed), do: {:ok, Normalizer.normalize_seed(seed)}

  defp validate_winner_count(n, _participants) when not is_integer(n) or n < 1 do
    {:error, {:invalid_winner_count, n}}
  end

  defp validate_winner_count(n, participants) when n > length(participants) do
    {:error, {:invalid_winner_count, n}}
  end

  defp validate_winner_count(_n, _participants), do: :ok

  defp validate_algorithm_version(version) when version in @supported_algorithm_versions, do: :ok

  defp validate_algorithm_version(version),
    do: {:error, {:unsupported_algorithm_version, version}}

  defp participants_hash(participants, version) do
    participants
    |> Serializer.serialize(version)
    |> Hash.sha256()
  end

  defp pick_from_shuffle(participants, seed, n, algorithm_version) do
    shuffled = shuffle_indexed(participants, seed, algorithm_version)
    picked = Enum.take(shuffled, n)

    winners = Enum.map(picked, fn {_hash, _idx, p} -> p end)
    indexes = Enum.map(picked, fn {_hash, idx, _p} -> idx end)
    {winners, indexes}
  end

  defp shuffle_indexed(participants, seed, "1.0.0") do
    participants
    |> Enum.with_index()
    |> Enum.map(fn {p, idx} ->
      hash = Hash.sha256(seed <> p)
      {hash, idx, p}
    end)
    |> Enum.sort_by(fn {hash, _idx, _p} -> hash end)
  end

  defp shuffle_indexed(participants, seed, "1.0.1") do
    participants
    |> Enum.with_index()
    |> Enum.map(fn {p, idx} ->
      hash = Hash.sha256(seed <> p)
      {hash, idx, p}
    end)
    |> Enum.sort_by(fn {hash, _idx, _p} -> hash end)
  end

  defp shuffle_indexed(participants, seed, "1.0.2") do
    participants
    |> Enum.with_index()
    |> Enum.map(fn {p, idx} ->
      # Include the canonical index to ensure duplicate entries are distinct and order-independent.
      hash = Hash.sha256([seed, ":", Integer.to_string(idx), ":", p])
      {hash, idx, p}
    end)
    |> Enum.sort_by(fn {hash, _idx, _p} -> hash end)
  end

  defp format_error({:invalid_winner_count, n}), do: "invalid winner count: #{inspect(n)}"

  defp format_error({:unsupported_algorithm_version, v}),
    do: "unsupported algorithm version: #{inspect(v)}"

  defp format_error(reason), do: inspect(reason)
end

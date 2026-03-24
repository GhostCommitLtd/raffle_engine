# RaffleEngine integration spec (recommended)

This document describes a production-grade, transparent draw workflow to use with `RaffleEngine` in a Phoenix API + Web UI.

## Goals

- Anyone can reproduce the draw result locally.
- No one party can pick outcomes by choosing the seed after seeing participants.
- The system can tolerate temporary drand/network failure without “inventing randomness”.

## Summary (recommended governance)

Use a **hybrid seed** derived from:

1. an organizer secret committed before the draw, and
2. a public randomness beacon value (drand), and
3. the frozen participant set hash.

And use a **deferred draw** fallback:

- If drand is unavailable at draw time, keep the draw in a pending state and retry until it succeeds.

## Data model (minimum fields)

You can implement this as one `draws` table plus one `tickets` (entries) table.

### `tickets`

Each row is one entry (duplicates allowed by design):

- `draw_id`
- `ticket_label` (string; email/username/etc)
- `inserted_at`

### `draws`

Recommended fields:

- `id`
- `status` one of:
  - `collecting` (tickets open)
  - `closed` (tickets frozen)
  - `pending_randomness` (closed, waiting for drand fetch)
  - `finalized` (winners stored)
  - `failed` (permanent error; optional)

Ticket freeze + proof:

- `closed_at`
- `participants_hash` (from RaffleEngine canonical participants)

Organizer commit–reveal:

- `seed_commit` (`sha256(organizer_secret)`)
- `seed_revealed_at` (optional; when you decide to reveal)

Drand proof (persist the response used):

- `drand_network` (string, e.g. `"mainnet"`)
- `drand_round` (integer)
- `drand_randomness` (string)
- `drand_signature` (string; optional but recommended)
- `drand_fetched_at`

Final derived seed + result:

- `final_seed` (string; the seed you pass to RaffleEngine)
- `algorithm_version` (store what RaffleEngine used, currently default is `"1.0.2"`)
- `winners` (array of strings)
- `indexes` (array of integers)
- `result_json` (optional: stored full draw/proof blob for easy export)

## Lifecycle (API/UI)

1. Create draw

- Generate organizer secret on the server (or accept from organizer).
- Store `seed_commit = sha256(organizer_secret)`.
- Set `status = collecting`.

2. Collect tickets

- Insert one ticket row per entry.
- Duplicates are allowed (two same labels = two tickets).

3. Close draw (freeze)

- Disallow further ticket insertions.
- Build participants input by loading all tickets and using a weighted representation if desired.
- Call `RaffleEngine.pick_n_winners_safe/4` only after `final_seed` is known; at close time compute and store `participants_hash`:
  - Either store the canonical expanded list you used (recommended for simplest reproducibility), OR store a canonical export file.

4. Determine drand round

- Choose a rule that is deterministic and visible. Example:
  - “first drand round whose timestamp is >= `closed_at`”.
- Store the chosen `drand_round`.

5. Fetch drand

- If fetch fails: set `status = pending_randomness` and retry (job/cron).
- On success: store `drand_randomness` (+ signature if available).

6. Derive final seed

Recommended derivation (simple and deterministic):

- `final_seed = sha256(organizer_secret <> ":" <> drand_randomness <> ":" <> participants_hash <> ":" <> draw_id)`

Store `final_seed`.

7. Finalize draw

- Call `RaffleEngine.pick_n_winners_safe(participants, final_seed, n)`.
- Store `winners`, `indexes`, `algorithm_version`, and (optionally) the full `draw` struct as JSON.
- Set `status = finalized`.

## Verification page (what to show)

To make verification easy for end users, publish:

- `algorithm_version`
- canonical participant list (or downloadable export) AND `participants_hash`
- `seed_commit`
- drand proof used: network, round, randomness (and signature if you store it)
- `final_seed`
- winners + indexes

Verification steps:

1. Confirm the participant export matches `participants_hash`.
2. Confirm `seed_commit == sha256(organizer_secret)` (if you reveal the organizer secret).
3. Confirm `final_seed` recomputes from the published inputs.
4. Run `RaffleEngine.pick_n_winners/4` with the published participants and `final_seed` and confirm winners match.

## Notes

- If you do not want to reveal `organizer_secret`, you can still be transparent by publishing only `final_seed` + drand proof + participants hash. Commit–reveal adds trust, but revealing is a product decision.
- For very large draws, storing the full expanded participant list can be big. Start simple; optimize later only if needed.

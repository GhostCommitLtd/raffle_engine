# Contributing

Thanks for your interest in contributing to RaffleEngine.

## Development setup

- Elixir: `~> 1.14`

Install dependencies:

```bash
mix deps.get
```

Run tests:

```bash
mix test
```

Format code:

```bash
mix format
```

Compile with warnings as errors:

```bash
mix compile --warnings-as-errors
```

## What to include in PRs

- Tests for behavior changes (especially determinism and verification).
- If you change the algorithm or serialization, bump/introduce an `algorithm_version` so old draws remain verifiable.
- Keep public API changes minimal and documented.

## Reporting security issues

Please do not open a public issue for security-sensitive reports. Contact the maintainers privately.

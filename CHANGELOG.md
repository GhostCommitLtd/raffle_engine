# Changelog

This project follows a lightweight changelog format.

## 0.4.0

- Removed support for top-level weighted maps; callers should pass ordered list inputs instead.
- Added `original_participants` to prepared participant output and draw results.
- Accepted ordered weighted arrays/objects in list inputs, so callers do not need to pre-normalize JSON-style entries.
- Reject malformed ordered weighted entries instead of silently coercing them into plain labels.

## 0.3.0

- Deterministic duplicate-ticket support (participants can repeat and count as multiple entries).
- Weighted participant inputs supported (maps and list items like `{label, count}` / keyword pairs).
- Stronger verification (checks winners, participant hash, and winner indexes).
- Added `INTEGRATION.md`, `README.md`, CI workflow, and MIT license.

## 0.2.0

- Initial release: deterministic winner selection + verification.

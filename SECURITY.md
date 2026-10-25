# Security Policy

## Reporting a vulnerability

Please report security issues **privately** using GitHub's private vulnerability
reporting:

https://github.com/Primex-tech-labs/stellar-ros-bridge/security/advisories/new

Do **not** open a public issue, pull request, or discussion for a suspected
vulnerability. We aim to acknowledge reports within 72 hours and will keep you
updated on remediation.

## Scope

Areas we consider security-sensitive:

- Signing, key handling, and any path that touches a Stellar secret key.
- The `TaskEscrow` Soroban contract (fund custody, release/refund logic).
- Proof verification and settlement authorization.
- Anything that could cause loss of funds or unauthorized task execution.

See [`docs/threat-model.md`](docs/threat-model.md) for the assets, actors,
trust boundaries, and mitigations we track.

## Handling secrets

- Never commit `.env` files, secret keys, or seed phrases. `.env` is gitignored;
  use `.env.example` as a template.
- No real keys in tests, fixtures, examples, or CI.
- Treat any credential pasted into an issue, PR, or chat as compromised and
  rotate it immediately.

## Supported versions

The project is pre-1.0; only the `main` branch is supported. Fixes are applied
to `main`.

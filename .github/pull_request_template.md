<!--
Keep PRs focused: one issue per PR. Conventional Commits in the title.
-->

## Summary

<!-- What changed and why, in a few sentences. -->

Closes #

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / internal
- [ ] Documentation
- [ ] Tests / tooling

## Security review

<!--
Complete this section when the PR touches signing, key handling, transaction
construction, authorization, replay protection, escrow/settlement logic,
storage, or network I/O. Otherwise mark N/A.
-->

- [ ] **Key handling:** secrets and signing keys are never logged, exposed in
      telemetry, or committed; keys are only read from the documented config.
- [ ] **Replay:** state-changing operations cannot be replayed (sequence
      numbers, nonces, timestamps, or ids are checked; retries are idempotent).
- [ ] **Authorization:** every state-changing path verifies the correct
      signer/role (requester, executor, or admin) before mutating state.
- [ ] **Escrow invariants:** funds can leave escrow only once, release and
      refund remain mutually exclusive, and proofs cannot be forged or reused.
- [ ] **Failure paths:** timeouts, retries, and partial writes cannot
      double-spend or leave inconsistent state.
- [ ] **Input/SSRF:** new inputs are validated and untrusted URLs or redirect
      targets remain behind the network guard.

## How it was verified

<!-- Paste the commands you ran and the relevant output. -->

```
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

## Checklist

- [ ] Assigned on the linked issue before starting.
- [ ] One issue per PR; no unrelated changes.
- [ ] Tests added or updated for new logic (edge cases included for money/signing/escrow paths).
- [ ] Public items documented; no build warnings.
- [ ] Docs updated where behavior changed.
- [ ] No secrets, keys, or credentials committed.

## Notes for reviewers

<!-- Design trade-offs, follow-ups, or anything that needs a closer look. -->

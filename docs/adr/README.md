# Architecture decision records

Architecture decision records (ADRs) capture **why** the project is built the
way it is. The design itself lives in [`docs/architecture.md`](../architecture.md);
an ADR records the context, the decision, and the consequences at the time it
was made.

## When to write an ADR

Write an ADR when a change:

- alters crate or module boundaries, trait signatures, or dependency direction;
- changes the on-chain contract interface or the settlement lifecycle;
- introduces a new external dependency, transport, or trust boundary;
- resolves a trade-off that a future contributor is likely to revisit.

Small fixes and purely additive documentation do not need an ADR.

## Process

1. Copy [`template.md`](template.md) to `ADR-NNNN-short-title.md`, using the next
   four-digit number.
2. Open it as **Proposed** in a pull request.
3. Discuss on the PR. When merged, set the status to **Accepted**.
4. Never rewrite an accepted ADR in place. Supersede it with a new ADR and link
   both ways.

## Index

| ADR | Title | Status |
| --- | --- | --- |
| [ADR-0001](ADR-0001-crate-split.md) | Split the bridge into core, ROS, Stellar, and node crates | Accepted |

## Template

- [`template.md`](template.md)

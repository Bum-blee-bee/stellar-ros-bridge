# ADR-0001: Split the bridge into core, ROS, Stellar, and node crates

- **Status:** Accepted
- **Date:** 2026-10-25
- **Deciders:** Stellar ROS Bridge maintainers
- **Related:** [#63](https://github.com/Primex-tech-labs/stellar-ros-bridge/issues/63), [`docs/architecture.md`](../architecture.md)

## Context

The bridge connects a ROS 2 robot graph to the Stellar network. Those two
worlds have very different requirements:

- ROS 2 code needs a sourced ROS 2 installation and, for the native transport,
  `rclrs` and its runtime libraries. Many contributors and CI runners do not
  have ROS 2 installed.
- Stellar code needs Soroban RPC, transaction building, signing, and XDR
  handling. It must never be linked into code that runs on a robot unless the
  robot actually settles payments.
- The task lifecycle is the part most likely to contain bugs that cost money
  (double release, settling an unproven task, accepting an expired task). It
  must be testable with fast, offline, deterministic tests.

Putting everything in one crate would force every build to pull in all
dependencies, make feature-flag combinations hard to reason about, and couple
the money-critical state machine to the transport and payment implementations.

## Decision

Split the workspace into small crates with explicit boundaries:

| Crate | Responsibility | May depend on |
| --- | --- | --- |
| `bridge-core` | Domain types, `Transport`/`Settlement`/`Clock` traits, error model, lifecycle state machine. No I/O. | No ROS 2 or Stellar crates |
| `ros-bridge` | Implements `Transport` over rosbridge_suite JSON-over-WebSocket (default) or `rclrs` behind the `ros` feature. | `bridge-core`, ROS/WebSocket libraries |
| `stellar-bridge` | Implements `Settlement` against the TaskEscrow contract over Stellar RPC. | `bridge-core`, Soroban/Stellar libraries |
| `bridge-node` | Runtime binary: wires a `Transport` to a `Settlement`, drives the lifecycle, serves health endpoints. | all of the above |
| `example-robot` | `TaskExecutor` implementation used by the simulated and native robot examples. | `bridge-core` |

The rule that makes the split useful is: **`bridge-core` never depends on ROS 2
or Stellar.** Integrations are expressed as traits (`Transport`, `Settlement`,
`Clock`) and injected into `BridgeNode`, so the lifecycle can be exercised with
mocks and each adapter can evolve and be released independently.

The escrow contract (`contracts/task-escrow`) stays outside the Cargo workspace
because it is compiled for `wasm32v1-none` with the Soroban SDK and has a
different build target and test harness.

## Consequences

### Positive

- `cargo build`, `cargo test`, `cargo clippy`, and `cargo doc` work without ROS
  2 or network access for `bridge-core`, `stellar-bridge`, and `bridge-node`.
- Money-critical lifecycle logic is unit-tested with mocks and an injected
  clock instead of real robots or a live network.
- Optional heavy integrations only affect the crate that owns them. The ROS
  native path is isolated behind `--features ros`.
- Reviewers can see at a glance whether a change crosses a trust boundary.

### Negative / trade-offs

- More crates, manifests, and re-exports to maintain.
- Some types must be duplicated or mapped at the adapter boundary (for example
  decoding Soroban XDR into `TaskState`).
- A change to a core trait can require coordinated changes in several crates.

### Follow-ups

- Keep the dependency direction enforced in review; see the crate table above.
- Record further significant decisions as ADRs in this directory.

## Alternatives considered

- **Single crate with feature flags.** Rejected: feature unification makes it
  easy to accidentally compile Stellar dependencies into robot builds, and the
  test suite would need to branch on features.
- **Two crates (`core` + `node`).** Rejected: it would put ROS and Stellar
  dependencies back into one binary crate and lose the isolation between
  transports and settlement.
- **Separate repositories per adapter.** Rejected at this stage: the project is
  small, and a single workspace keeps atomic changes and CI simpler. The crate
  boundaries leave the option open for later.

## References

- [`docs/architecture.md`](../architecture.md) — crate responsibilities, data
  flow, and settlement invariants.
- [`crates/bridge-core/src/traits.rs`](../../crates/bridge-core/src/traits.rs)
- [`crates/bridge-core/src/driver.rs`](../../crates/bridge-core/src/driver.rs)

# Roadmap

This is a phased plan. Each milestone lists the outcome, not a date. Work is
sliced into Wave-sized issues in `.wave/issues.md`.

## M0 — Foundation (done)

**Outcome:** a compiling workspace with a stable domain model and CI.

- [x] `bridge-core` domain types + error model with round-trip tests
- [x] Repository scaffolding, CI (fmt/clippy/test), label + issue process
- [x] Documented architecture and local dev setup

## M1 — Task lifecycle off-chain

**Outcome:** the whole task lifecycle works with mocks — no chain, no robot.

- [x] `Transport` and `Settlement` traits
- [x] `bridge-node` state machine (`Announced → … → Settled`) with unit tests
- [x] Mock transport + mock settlement used in integration tests

## M2 — Stellar settlement

**Outcome:** a task can be escrowed and released on **testnet**.

- [x] `TaskEscrow` Soroban contract with the invariants from `architecture.md`
- [ ] `stellar-bridge` client: create/accept/proof/release/refund
- [ ] Testnet bootstrap script (account + friendbot + deploy)
- [ ] End-to-end test against a local Soroban sandbox

## M3 — ROS 2 integration

**Outcome:** a real ROS 2 node drives the lifecycle.

- [ ] `ros-bridge` `rclrs` transport for capability/task/proof topics
- [ ] Example robot package that advertises a capability and completes a task
- [ ] CI job that builds `ros-bridge` under ROS 2 Jazzy

## M4 — Hardening

**Outcome:** safe enough for a pilot fleet.

- [ ] Dispute resolution path and maintainer review flow
- [ ] Fuzz/negative tests for proof verification and escrow math
- [ ] Observability: tracing spans, metrics, and a health endpoint
- [ ] Threat model and security review checklist

## Non-goals (for now)

- Multi-chain settlement.
- A hosted service or dashboard.
- Real-money (mainnet) operation before M4 is complete.

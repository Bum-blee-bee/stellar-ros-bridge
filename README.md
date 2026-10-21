# Stellar ROS Bridge

> A Rust framework that connects [ROS 2](https://ros.org) robots to the
> [Stellar](https://stellar.org) network, letting machines advertise
> capabilities, accept paid tasks, and settle rewards on-chain via
> [Soroban](https://stellar.org/soroban) smart contracts.

[![CI](https://github.com/Primex-tech-labs/stellar-ros-bridge/actions/workflows/ci.yml/badge.svg)](https://github.com/Primex-tech-labs/stellar-ros-bridge/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Why this exists

Robots and autonomous fleets increasingly need to transact: rent out idle
capacity, pay for compute, settle for a delivered task, or coordinate across
organizations that do not trust one another. Today that coordination is glued
together with bespoke APIs, spreadsheets, and trust.

Stellar ROS Bridge closes that gap:

- **ROS 2** is where the robot's capabilities, sensors, and actions already live.
- **Stellar + Soroban** provide fast, low-cost, programmable settlement with a
  mature wallet and asset ecosystem.

This project is the missing seam between the two: a typed, testable, Rust-native
bridge that turns a robot's ROS 2 graph into a set of tradable on-chain services.

## Core ideas

| Concept | Description |
| --- | --- |
| **Capability** | A robot's advertised service (e.g. `navigate`, `pick`, `inspect`) published on a ROS 2 topic. |
| **Task** | A unit of paid work matching a Capability, with parameters, reward, and deadline. |
| **Escrow** | A Soroban contract that holds the reward until the task is proven complete. |
| **Proof** | Evidence a task finished (signed telemetry digest, sensor attestation, or maintainer sign-off). |
| **Settlement** | On-chain release of escrowed funds to the robot's Stellar account. |

## Architecture

```
            ROS 2 graph                         Stellar network
   +---------------------------+        +----------------------------+
   |  /robot/capabilities      |        |  TaskEscrow (Soroban)      |
   |  /robot/tasks (in)        |  <-->  |  TaskMarket (Soroban)      |
   |  /robot/proofs (out)      |        |  Assets / XLM              |
   +-------------+-------------+        +-------------+--------------+
                 |                                      |
                 |            stellar-ros-bridge        |
                 +--------------------------------------+
                        bridge-node (runtime)
                   crates/bridge-core  (domain types)
                   crates/ros-bridge   (rclrs integration)
                   crates/stellar-bridge (Soroban client)
```

See [`docs/architecture.md`](docs/architecture.md) for the full design and
[`docs/roadmap.md`](docs/roadmap.md) for the phased plan.

## Repository layout

```
crates/
  bridge-core/      # Domain types, state machine, driver, mocks (no I/O)
  ros-bridge/       # ROS 2 configuration (rclrs transport next)
  stellar-bridge/   # Soroban/Stellar RPC client (next)
  bridge-node/      # Binary: config, demo lifecycle, health server
contracts/
  task-escrow/      # Soroban escrow contract + tests (own workspace)
docs/               # Architecture, roadmap, contributor guides
.wave/              # Drips Wave issue backlog and process notes
```

## Status

**Working vertical slice.** The following are implemented and tested:

- `bridge-core`: validated domain types, the task state machine, `Transport` /
  `Settlement` / `Clock` traits, mocks, and the `BridgeNode` driver
  (accept → execute → prove → release/refund).
- `contracts/task-escrow`: a Soroban escrow with requester/executor auth,
  deadlines, proof digests, TTL bumps, release/refund and unit tests.
- `bridge-node --demo`: runs the full lifecycle with in-memory collaborators.

Still to come: the `rclrs` ROS 2 transport, a live Soroban settlement client in
`stellar-bridge`, and a testnet end-to-end run. See the
[roadmap](docs/roadmap.md) and the open
[Stellar Wave issues](https://github.com/Primex-tech-labs/stellar-ros-bridge/issues?q=is%3Aissue+label%3A%22Stellar+Wave%22).

## Getting started

Prerequisites:

- Rust (see `rust-toolchain.toml` — installed automatically by rustup)
- ROS 2 (Jazzy or newer) only when working on the `rclrs` transport (not
  implemented yet)
- A Stellar testnet account and funded key for the live settlement client (not
  implemented yet; the included escrow tests run offline)

```bash
git clone https://github.com/Primex-tech-labs/stellar-ros-bridge
cd stellar-ros-bridge
cargo build --workspace
cargo test --workspace

# Run the lifecycle once with an in-memory transport and settlement:
cargo run -p bridge-node -- --demo

# Contract tests (no Stellar network required):
cargo test --manifest-path contracts/task-escrow/Cargo.toml
```

## Contributing

We run contributions through the **Drips Wave** program for the Stellar
ecosystem. Please read:

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — workflow, commit convention, review bar
- [`docs/issue-guide.md`](docs/issue-guide.md) — how our issues are written
- [`.wave/issues.md`](.wave/issues.md) — the current Wave backlog

Issues labeled **`Stellar Wave`** are in scope for a Wave. Ask to be assigned
before starting; unassigned PRs may be closed to keep the sprint fair.

## License

Apache-2.0. See [`LICENSE`](LICENSE).

## ROS bridge parameters

The ROS bridge configuration module supports ROS 2 YAML parameter files. The
example defaults are in `config/ros-bridge-params.yaml`:

- `capabilities_topic`: `/robot/capabilities`
- `tasks_topic`: `/robot/tasks`
- `proofs_topic`: `/robot/proofs`
- `ros_domain_id`: `0` (valid range: 0–232)

Use a copy of the example file to customize these values for your deployment.
The `ros-bridge` configuration parser can be tested without a ROS 2
installation. The current repository still has ROS transport scaffolding only;
a running ROS node must load this configuration when the transport is
implemented.

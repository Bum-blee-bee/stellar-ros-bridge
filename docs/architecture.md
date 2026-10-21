# Architecture

Stellar ROS Bridge sits between a ROS 2 robot graph and the Stellar network.
It is split into small crates so that the domain logic stays pure and testable,
and so that the heavy external dependencies (ROS 2 and Stellar RPC) live only
where they are needed.

## Crates

| Crate | Responsibility | External deps |
| --- | --- | --- |
| `bridge-core` | Domain types (`Capability`, `Task`, `TaskId`, `Proof`, `Reward`), traits (`Transport`, `Settlement`), error model. No I/O. | none |
| `ros-bridge` | Implements the ROS 2 side of `Transport` using `rclrs`. Publishes/subscribes to the capability, task, and proof topics. | ROS 2 (Jazzy+) |
| `stellar-bridge` | Implements the `Settlement` trait against Soroban contracts and the Stellar RPC/Horizon. Signing, submission, confirmation. | Stellar RPC |
| `bridge-node` | The runtime binary. Wires a `Transport` to a `Settlement`, runs the task lifecycle state machine. | all of the above |

The key design rule: **`bridge-core` never depends on ROS or Stellar.** Both
integrations are behind traits, which makes the lifecycle logic unit-testable
with mocks and keeps Wave issues cleanly scoped to one crate.

## Data flow

```
 robot                 ros-bridge              bridge-node              stellar-bridge        Stellar
   |  capability msg  ------>|                      |                          |                 |
   |                         |  Capability          |                          |                 |
   |                         |--------------------->|                          |                 |
   |                         |                      |  register/find task      |                 |
   |                         |                      |------------------------->|  read contract  |
   |  task request  <--------------------------------|                          |                 |
   |  (execute)  ----------->|  Task                |                          |                 |
   |                         |--------------------->|  escrow funded?          |                 |
   |                         |                      |------------------------->|                 |
   |  proof (signed) ------->|  Proof               |                          |                 |
   |                         |--------------------->|  verify + settle         |                 |
   |                         |                      |------------------------->|  release()      |
```

## Domain model (draft)

```rust
// bridge-core

pub struct Capability {
    pub id: String,          // e.g. "navigate", "pick", "inspect"
    pub version: u32,
    pub units: String,       // e.g. "per_meter", "per_pick"
    pub metadata: Metadata,  // free-form, JSON-compatible
}

pub struct Task {
    pub id: TaskId,
    pub capability: String,
    pub params: Metadata,
    pub reward: Reward,      // asset + amount
    pub deadline: Timestamp,
    pub requester: AccountId,
}

pub struct Proof {
    pub task_id: TaskId,
    pub digest: [u8; 32],    // hash of telemetry / deliverable
    pub signer: PublicKey,
    pub signature: Signature,
}

pub enum TaskState {
    Announced,
    Requested,
    Accepted,
    InProgress,
    ProofSubmitted,
    Settled,
    Disputed,
    Expired,
}
```

> These types are implemented in `crates/bridge-core/src/types.rs` with
> validation, serde round-trip tests and lifecycle tests.

## Settlement contract (implemented)

`contracts/task-escrow` implements the escrow. Entry points:

```rust
fn create_task(env, requester, capability, token, amount, deadline) -> Result<TaskId, Error>;
fn accept_task(env, task_id, executor) -> Result<(), Error>;
fn submit_proof(env, task_id, executor, digest) -> Result<(), Error>;
fn release(env, task_id) -> Result<(), Error>;
fn refund(env, task_id) -> Result<(), Error>;   // deadline passed
fn get_task(env, task_id) -> Option<Task>;
```

Safety invariants, covered by `contracts/task-escrow/src/test.rs`:

1. Funds can leave escrow exactly once, via `release` **or** `refund` — never both.
2. Only the accepted executor can submit a proof, and only before `deadline`.
3. `release` requires a stored proof; the requester authorizes it.
4. `refund` only succeeds after `deadline` and is requester-authorized.
5. State writes happen before token transfers, and persistent entries are
   TTL-bumped on every read/write.

## Identity & keys

- Each robot maps to a Stellar account. The robot's signing key lives in the
  operator's environment (never in the repo).
- ROS 2 node identity is separate from the Stellar account; the bridge holds the
  mapping. Linking the two is out of scope for the first milestones.

## Local development

1. Install Rust via rustup (toolchain pinned in `rust-toolchain.toml`).
2. For ROS work: install ROS 2 Jazzy and `source /opt/ros/jazzy/setup.bash`.
3. For Stellar work: create a testnet account and fund it via friendbot; put
   the secret in an environment variable, e.g. `STELLAR_SECRET` (see `.env.example`).
4. `cargo build --workspace` and `cargo test --workspace` run offline. The
   `ros` feature is still a placeholder; the rclrs transport will require a
   sourced ROS 2 environment when it lands.

## Cross-cutting concerns

- **Observability:** structured `tracing` spans keyed by `TaskId`.
- **Time:** all deadlines are Stellar ledger time, not wall clock, to avoid skew.
- **Failure:** a failed settlement never blocks the robot loop; tasks are
  retried or refunded per the state machine.

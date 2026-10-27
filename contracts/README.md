# Soroban contracts

On-chain contracts for Stellar ROS Bridge, written in Rust against
[`soroban-sdk`](https://docs.rs/soroban-sdk).

```
contracts/
  task-escrow/        # TaskEscrow: create/accept/prove/release/refund
    Cargo.toml
    src/lib.rs
    src/test.rs
```

## TaskEscrow

The contract holds a task reward in escrow and releases it to the robot only
after the requester accepts a proof:

- `create_task(requester, capability, token, amount, deadline)` transfers the
  reward into the contract and assigns a task id. The requester authorizes it.
- `accept_task(task_id, executor)` lets a robot claim an open, unexpired task.
- `submit_proof(task_id, executor, digest)` records a 32-byte proof digest
  before the deadline; only the accepted executor may call it.
- `release(task_id)` pays the executor once a proof exists. Requester-authorized.
- `refund(task_id)` returns the reward after the deadline if the task was not
  released. Requester-authorized.
- `get_task(task_id)` returns the stored state.

Safety invariants (covered by `src/test.rs`):

1. A task can only be released once, and only after a proof.
2. Release and refund are mutually exclusive.
3. Only the accepted executor can submit proof.
4. Proofs cannot be submitted, and tasks cannot be accepted, after the deadline.
5. The requester cannot accept the task they created.
6. Persistent entries are TTL-bumped on every read/write.

## Build and test

```bash
cd contracts/task-escrow
cargo test                       # unit tests with soroban-sdk testutils
cargo build --release --target wasm32v1-none
# or, with stellar-cli installed:
stellar contract build
```

The contract is its own Cargo workspace so Soroban dependencies do not leak into
the bridge crates.

## Deploy the escrow

`scripts/deploy-escrow.sh` (bash) and `scripts/deploy-escrow.ps1` (Windows)
make deployment repeatable: they build the contract, run Binaryen's `wasm-opt`
(`-Oz --strip-debug`), and deploy the optimized wasm with `stellar-cli`. The
contract id is printed at the end.

Prerequisites:

- Rust with the `wasm32v1-none` target (installed automatically by the script
  when `rustup` is available). `soroban-sdk` 28 rejects
  `wasm32-unknown-unknown` on Rust 1.82+, so `wasm32v1-none` is the default.
  Set `WASM_TARGET=wasm32-unknown-unknown` only for older SDK/toolchain
  combinations.
- [Binaryen](https://github.com/WebAssembly/binaryen/releases) (`wasm-opt` on
  `PATH`, or set `WASM_OPT=/path/to/wasm-opt`).
- `stellar-cli` v25 or newer.
- A funded source account on the target network.

Credentials are read from the environment only and are never written to disk or
printed:

| Variable | Purpose |
| --- | --- |
| `STELLAR_SECRET` | Secret key (`S...`) of the funded source account. |
| `STELLAR_SOURCE` | Alternative: a `stellar keys` identity name. |
| `STELLAR_NETWORK` | Target network, default `testnet`. |
| `WASM_TARGET` | Rust target, default `wasm32v1-none`. |
| `WASM_OPT` | Path to `wasm-opt`, default `wasm-opt`. |

```bash
# Funded testnet account; the secret stays in the environment.
export STELLAR_SECRET=S...
scripts/deploy-escrow.sh
# ...
# TaskEscrow deployed: C...
# export TASK_ESCROW_CONTRACT_ID=C...
```

```powershell
$env:STELLAR_SECRET = "S..."
./scripts/deploy-escrow.ps1
```

To validate the build and `wasm-opt` step without deploying (for example in CI):

```bash
scripts/deploy-escrow.sh --build-only
```

```powershell
./scripts/deploy-escrow.ps1 -BuildOnly
```

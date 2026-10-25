# Threat model

This document enumerates the assets, actors, trust boundaries, and failure modes
of Stellar ROS Bridge before the project scales beyond a single robot and a
single escrow contract. It is a living document: update it when an architecture
decision ([`docs/adr/`](adr/README.md)) or contract interface changes.

- **Scope:** `crates/` (bridge core, ROS transport, Stellar settlement, node) and
  `contracts/task-escrow`.
- **Out of scope:** the security of Stellar consensus, the Stellar Asset
  Contract / token implementation, ROS 2 itself, and the physical safety
  certification of a robot (see [Out of scope](#out-of-scope)).
- **Status:** reviewed 2026-10-25. Each threat below is either mitigated in the
  current code or tracked by an open issue.

## System model

```
 requester wallet                                   executor wallet
       |                                                  |
       | create_task / release / refund                   | accept_task / submit_proof
       v                                                  v
 +------------------------------------------------------------------+
 |                    TaskEscrow Soroban contract                   |
 |  escrow balance, task state, proof digest, deadlines, auth        |
 +------------------------------------------------------------------+
              ^                                   ^
              | signed Soroban transactions       | proofs / task ids
              |                                   |
       +--------------+                    +--------------+
       | stellar-     |                    | bridge-node  |
       | bridge       |<--- Settlement ----|              |
       +--------------+      trait         +--------------+
                                                 |
                                          Transport trait
                                                 |
       +------------------+          +-------------------+
       | ros-bridge       |<-------->| ROS 2 graph       |
       | (rosbridge/rclrs)|  JSON    | (any participant) |
       +------------------+          +-------------------+
```

`bridge-core` owns the state machine and the traits; it performs no I/O. The
adapters (`ros-bridge`, `stellar-bridge`) and the runtime (`bridge-node`) sit on
either side of it. See [`docs/architecture.md`](architecture.md) for the crate
contract.

### Trust boundaries

| # | Boundary | What crosses it | Default trust |
| --- | --- | --- | --- |
| B1 | ROS 2 graph -> `ros-bridge` | `Task` JSON on a topic | **Untrusted.** rosbridge has no authentication by default. |
| B2 | `ros-bridge` -> `bridge-core` | Parsed `Task`, `Proof` | Semi-trusted: validated by serde, not authenticated. |
| B3 | `bridge-core` -> `stellar-bridge` | Signed contract calls | Trusted process boundary; the signing key is in memory. |
| B4 | `stellar-bridge` -> Stellar RPC | Transactions, simulations | Network boundary; HTTPS by default. The RPC can censor or delay. |
| B5 | `TaskEscrow` -> token contract | `transfer` calls | On-chain; authorization is enforced by each contract. |
| B6 | Operator environment -> process | `STELLAR_SECRET`, config | Secret; must never be logged or committed. |
| B7 | CI -> release artifacts | Wasm and binaries | Currently unsigned/unattested (tracked in #69). |

## Assets

| Asset | Why it matters | Where it lives |
| --- | --- | --- |
| **Funds in escrow** | A bug or theft loses real money. | `TaskEscrow` balance held by the contract. |
| **Signing keys** | `STELLAR_SECRET` authorizes every settlement call; a robot key authorizes proofs. | Operator environment, process memory (`Keypair`), never the repo. |
| **Task integrity** | Capability, params, reward, deadline, and requester/executor identity determine what work is paid for. | `Task` messages in ROS; `Task` records on-chain. |
| **Proof authenticity** | The digest is what the requester inspects before releasing funds. | `Proof` messages; `proof_digest` in contract storage. |
| **Settlement availability** | Stuck tasks lock funds until the deadline expires. | `bridge-node` process, RPC endpoint, ROS graph. |
| **Configuration & deployment** | Wrong network, contract id, or wasm hash can misdirect funds. | `.env`, contract deployment records, CI. |
| **Contributor credentials** | Maintainer/CI access can alter code or releases. | GitHub accounts, tokens, CI secrets. |

## Actors

| Actor | Capabilities | Trust level |
| --- | --- | --- |
| **Requester** | Creates tasks, funds escrow, releases or refunds. | Authorized by `require_auth` on the requester address. |
| **Executor / robot operator** | Accepts tasks, produces proofs, submits them, receives payment. | Authorized by `require_auth`; must have been accepted for the task. |
| **Bridge node operator** | Runs `bridge-node`, holds the settlement key, configures topics. | Trusted with the executor (or requester) key. |
| **ROS graph participant** | Publishes/subscribes on bridge topics; may be any process on the network. | **Untrusted** unless the graph is isolated/authenticated. |
| **Stellar RPC provider** | Supplies account state, simulation results, ledger data. | Semi-trusted; can censor or return stale data. |
| **Stellar network** | Orders and finalizes transactions, enforces `require_auth`. | Trusted for consensus and authorization. |
| **Maintainer / CI** | Merges code, builds release artifacts. | Trusted, but a compromised account is high impact. |
| **Anonymous attacker** | Can publish ROS messages on a reachable graph, submit transactions, and read public chain data. | Untrusted. |

## Threat catalog

Each row has a mitigation already present in the code, an operational
mitigation, or a tracked issue. The **Status** column uses:

- **Mitigated** — control exists and is exercised by tests.
- **Partial** — a control exists but leaves a documented residual risk.
- **Tracked #N** — the gap is owned by an open issue.

| ID | STRIDE | Threat | Impact | Mitigation / tracking | Status |
| --- | --- | --- | --- | --- | --- |
| T-01 | Spoofing | A rogue actor submits a fabricated proof for a task, hoping to be paid. | Funds released without work. | Contract stores the digest only from the accepted executor (`submit_proof` checks `Status::Accepted`, `task.executor == executor`, `require_auth`). `release` additionally requires `Status::ProofSubmitted` and requester auth. `BridgeNode` rejects a proof whose `task_id` differs from the task (`NodeError::WrongProof`). | Partial — the requester must still verify the work. Tracked #25, #54 (on-chain signature verification). |
| T-02 | Spoofing | A proof digest is replayed for a different task or after settlement. | Double payment or payment for unrelated work. | The contract binds a digest to one task id and one `Accepted -> ProofSubmitted -> Released` transition; `proof.task_id` is checked before submission. | Partial — digests are not checked for uniqueness. Tracked #33. |
| T-03 | Elevation | An attacker accepts a task on behalf of a robot, or the requester accepts their own task. | Hijacked work or self-dealing. | `accept_task` calls `executor.require_auth()`, requires `Status::Open`, rejects `requester == executor`, and rejects expired tasks. | Mitigated (`contracts/task-escrow/src/test.rs`). |
| T-04 | Elevation | Unauthorized release or refund. | Funds moved without consent. | `release` and `refund` call `requester.require_auth()` and check the status; `release` requires a stored proof. | Mitigated (`contracts/task-escrow/src/test.rs`). |
| T-05 | Tampering | Double release/refund or reentrancy through the token contract. | Escrow drained twice. | Status is written to `Released`/`Refunded` **before** `transfer`; `release` only accepts `ProofSubmitted`, `refund` only `Open`/`Accepted` after the deadline. | Mitigated; fuzzing tracked #32. |
| T-06 | DoS (griefing) | An executor accepts a task and disappears, locking the reward until the deadline. | Funds temporarily unavailable; requester must wait. | `refund` is available to the requester once `ledger.timestamp() >= deadline`. Deadlines bound the lockup. | Partial — no stake/slashing. Tracked #28 (dispute path). |
| T-07 | DoS (griefing) | Flooding the bridge with tasks or huge payloads to exhaust CPU/memory. | Node stops settling; other tasks miss deadlines. | Tasks are only acted on after on-chain acceptance; creation costs funds and a signature. Malformed frames fail closed (`parse_task_frame`). Deploy rosbridge on a trusted network. | Partial — no built-in rate limit; observability tracked #58. |
| T-08 | Info disclosure / Elevation | The executor's signing key is stolen (env leak, logs, backups, malware). | Attacker submits proofs and collects escrow, or drains the account. | The secret is read from `STELLAR_SECRET` only, `SecretString` and `StellarConfig`/`StellarSettlement` `Debug` redact it, and configuration errors never echo it. Use a dedicated low-balance hot account. | Partial — no HSM or rotation. Tracked #42 (loader/redaction hardening). |
| T-09 | Info disclosure | The requester's signing key is stolen. | Attacker releases escrow to a colluding executor. | Same redaction controls; run separate requester and executor clients with least privilege; keep high-value requester keys offline. | Partial. Tracked #42, #37 (mainnet guard). |
| T-10 | Info disclosure | Secrets leak through logs, error strings, or committed `.env` files. | Key compromise. | `SecretString(***)` in `Debug`; `.env` is git-ignored; `.env.example` has placeholders; `SECURITY.md` requires rotation after exposure. | Mitigated; review checklist tracked #68. |
| T-11 | Tampering / Info disclosure | A malicious or compromised RPC endpoint returns false task state or withholds results. | Wrong settlement decision or stuck tasks. | TLS by default (`allow_http` is opt-in for local sandboxes); all state-changing operations are authorized on-chain; the contract id is configured explicitly. | Partial — RPC can censor/delay. Use your own RPC for production; retry tracked #59. |
| T-12 | Spoofing / Tampering | A rogue ROS participant publishes a forged `Task` or capability on a bridge topic. | Robot executes attacker-chosen work or advertises false capability. | The transport treats topic data as untrusted input and rejects malformed payloads. Payment fields that matter (`reward`, `amount`, `deadline`) are enforced on-chain. Isolate or authenticate the ROS graph (VLAN, SROS 2, TLS rosbridge). | Partial — task params are not reconciled with on-chain state. Tracked #75. |
| T-13 | Tampering | Malicious task parameters exploit the robot executor (unsafe motion, oversized payloads, injection). | Physical damage or executor crash. | Execution is behind `TaskExecutor`; the default `UnsupportedExecutor` refuses work; `example-robot` validates capability and hashes only known fields. Params are not executed by the bridge itself. | Partial — executors must validate params. Tracked #20 (shared validation). |
| T-14 | Tampering | Clock skew between the bridge and the ledger causes a settle/refund race. | A transaction is rejected or a proof is submitted late. | `accept_task`/`submit_proof`/`refund` all compare against `env.ledger().timestamp()`; `BridgeNode` checks the deadline before executing and fails closed by refunding. | Partial — bridge uses an injected local clock. Tracked #43 (ledger-time clock). |
| T-15 | Spoofing | A rogue robot advertises a capability and accepts tasks it cannot perform. | Requester pays for non-existent work; task delays. | Capability advertisement is informational; payment still requires an accepted executor, a proof, and explicit requester release. On-chain events expose the executor identity. Pin the executor address for high-value tasks. | Partial — no capability registry/attestation. Tracked #54. |
| T-16 | Tampering | A compromised dependency, build script, or release process ships malicious binaries. | Arbitrary code execution in operators' environments; key theft. | CI runs fmt/clippy/tests on every PR; secrets are not available to fork PRs. Release artifacts are not yet attested. | Tracked #69 (SLSA provenance), #7 (`cargo-audit`), #2 (Dependabot). |
| T-17 | Tampering | Deploying the wrong contract id, wasm, or network by mistake. | Funds sent to an unintended contract or mainnet. | The contract id is explicit config; `docs/architecture.md` records the verified testnet deployment and wasm hash; `allow_http` defaults off. | Partial. Tracked #36 (deploy script), #37 (mainnet guard). |
| T-18 | DoS | A node crash or restart loses in-flight tasks; escrow stays locked. | Tasks are not settled until the deadline or manual intervention. | State is authoritative on-chain, so a restarted node can resume; funds remain refundable after the deadline. | Tracked #75 (resume from on-chain state), #60 (drain on shutdown), #59 (retry/backoff). |

## Priority threats

The issue that introduced this document calls out spoofed proofs, griefing, and
key theft. Their current posture:

### Spoofed proofs

The contract is the last line of defence. It never accepts a proof from an
account other than the one that accepted the task, and it never releases funds
without a stored proof and the requester's signature. What is **not** verified
on-chain is the proof *signature*: `submit_proof` stores a 32-byte digest only.
That means a malicious executor can store an arbitrary digest. The requester
must therefore check the work before calling `release`. This is acceptable for
the current single-operator deployment but is the highest-priority gap for
scaling; on-chain signature verification is tracked in #25, with robot-side
signing in #54.

### Griefing

The main griefing vector is economic: accept a task and stall until the
deadline, or flood the node with messages. Griefing is bounded by the deadline
and by the cost of creating an escrow, and it cannot move funds. There is no
slashing or reputation system yet; a dispute path is tracked in #28, and node
observability in #58. Operators should run rosbridge on a trusted network and
alert on task age.

### Key theft

Keys are never serialized, and `Debug` output is redacted, but a compromised
host can still read `STELLAR_SECRET` from the process environment. Operational
mitigations:

- run the bridge on a dedicated host with a dedicated, low-balance hot account;
- keep requester keys offline for high-value tasks and use a separate executor
  client for `accept_task`/`submit_proof`;
- rotate a key immediately if it may have been exposed (see `SECURITY.md`);
- do not run with `STELLAR_ALLOW_HTTP=true` outside a local sandbox.

## Residual risks and accepted trade-offs

| Risk | Owner | Review trigger |
| --- | --- | --- |
| Proof payload/signature is not verified on-chain; requester judgement is the gate. | Contract maintainers | Before multi-operator scaling (#25, #54). |
| No proof-digest uniqueness check. | Contract maintainers | Before enabling public task creation (#33). |
| No rate limiting or admission control at the node/ROS boundary. | Node maintainers | When the bridge is exposed beyond a trusted ROS graph (#58). |
| Local clock can be skewed; transactions fail closed but may need retrying. | Node maintainers | When `Clock` is replaced by ledger time (#43). |
| No key rotation, HSM, or multi-sig support. | Operators | When escrow values justify hardware-backed signing. |
| Release artifacts are not attested. | Release maintainers | Next tagged release (#69). |

## Out of scope

- Correctness and liveness of Stellar consensus and the token contracts.
- Vulnerabilities in ROS 2, `rclrs`, rosbridge_suite, or the OS.
- Physical safety certification of robots and task executors.
- The honesty of the requester's verification of completed work.

## Review process

- Re-review this document when a change crosses a trust boundary (see the ADR
  criteria in [`docs/adr/README.md`](adr/README.md)).
- Every new threat needs a mitigation in the same PR, or an open issue linked in
  the **Status** column.
- Security reports follow [`SECURITY.md`](../SECURITY.md); do not open a public
  issue for a suspected vulnerability.

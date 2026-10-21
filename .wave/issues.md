# Stellar Wave — issue backlog

These are the genuine, Wave-sized issues for the current cycle. Each is written
following `docs/issue-guide.md`. Copy the body into GitHub using the **Wave
task** template, apply the labels, and assign one contributor per issue.

Points: **Trivial = 100**, **Medium = 150**, **High = 200**.

Legend: `⭐ = good first issue`

---


> **Status:** W-02, W-04, W-07, W-08 and W-09 are implemented on `main`
> (`bridge-core` domain/lifecycle/mocks and `contracts/task-escrow`). The
> remaining issues below are the open work for the next cycle.

## W-01 — Document the bridge message schema with examples

**Labels:** `Stellar Wave`, `documentation`, `area: docs`, `complexity: trivial` ⭐
**Points:** 100

### Description
Write `docs/messages.md` describing the ROS 2 message schema the bridge will
publish and consume: `Capability`, `Task`, `TaskRequest`, and `Proof`. This
gives contributors and robot authors a single reference before the types are
frozen in code.

### Requirements and context
- Cover each message: purpose, fields, types, units, and an example JSON payload.
- Cross-reference the draft types in `docs/architecture.md#domain-model-draft`.
- State which messages are robot→bridge vs bridge→robot.
- Definition of done: a new contributor can read the doc and understand the
  contract without reading Rust code.

### Suggested execution
- Branch: `docs/message-schema`
- Add `docs/messages.md`; link it from `README.md` and `docs/architecture.md`.

### Implement changes
- `docs/messages.md` with one section per message and a worked end-to-end example.
- Update the docs table in `README.md`.

### Test and commit
- No code tests; verify all internal doc links resolve.
- PR description includes the rendered doc outline.

### Example commit message
`docs: add ROS 2 message schema reference`

### Guidelines
- Assignment required before starting.
- PR description must include: `Closes #<issue_id>`.

---

## W-03 — Configure `cargo-deny` for licenses and advisories

**Labels:** `Stellar Wave`, `area: docs`, `complexity: trivial`
**Points:** 100

### Description
Add a `deny.toml` and a CI step so the workspace fails on disallowed licenses,
known advisories, and duplicate/banned crates.

### Requirements and context
- Allow `Apache-2.0`, `MIT`, and common permissive licenses; deny copyleft.
- Wire it into `.github/workflows/ci.yml` as a separate job.
- Definition of done: `cargo deny check` passes locally and in CI.

### Suggested execution
- Branch: `chore/cargo-deny`
- Add `deny.toml`; add a `deny` job to CI.

### Implement changes
- `deny.toml`
- CI job running `EmbarkStudios/cargo-deny-action`.

### Test and commit
- Paste local `cargo deny check` output in the PR.

### Example commit message
`chore: add cargo-deny license and advisory checks`

### Guidelines
- Assignment required before starting.
- PR description must include: `Closes #<issue_id>`.

---

## W-05 — Stellar testnet bootstrap script

**Labels:** `Stellar Wave`, `area: stellar`, `complexity: medium`
**Points:** 150

### Description
Add a script (`scripts/bootstrap-testnet.sh` or a small Rust bin) that creates a
testnet keypair, funds it via friendbot, and prints the public key plus a
redacted secret reference. It removes friction from every Stellar-related task.

### Requirements and context
- Must never print or write the raw secret to disk by default; use an env var.
- Idempotent: re-running does not error.
- Configurable RPC/horizon URL via env with sane defaults.

### Suggested execution
- Branch: `feat/testnet-bootstrap`
- Add script under `scripts/`; document usage in `docs/architecture.md`.

### Implement changes
- Bootstrap script + usage docs.

### Test and commit
- Run against testnet; include the public key and command output in the PR.

### Example commit message
`feat(tools): add Stellar testnet bootstrap script`

### Guidelines
- Assignment required before starting.
- PR description must include: `Closes #<issue_id>`.

---

## W-06 — `stellar-bridge` escrow client with mocked RPC tests

**Labels:** `Stellar Wave`, `area: stellar`, `complexity: medium`
**Points:** 150

### Description
Implement the `Settlement` trait for `stellar-bridge`: `create_task`,
`accept_task`, `submit_proof`, `release`, `refund`. Back it with a trait-based
RPC layer so tests use a mock instead of a live network.

### Requirements and context
- No live network calls in unit tests; abstract the RPC behind a trait.
- Map RPC/contract errors into `bridge-core` errors.
- Definition of done: happy path and error path covered by mock tests.

### Suggested execution
- Branch: `feat/stellar-settlement-client`
- Touch `crates/stellar-bridge/src/{lib.rs,client.rs,rpc.rs}`.

### Implement changes
- `Settlement` implementation + mockable RPC trait + tests.

### Test and commit
- `cargo test -p stellar-bridge`
- Paste output; list covered error cases.

### Example commit message
`feat(stellar): add escrow settlement client with mockable RPC`

### Guidelines
- Assignment required before starting.
- PR description must include: `Closes #<issue_id>`.

---

## W-10 — ROS 2 `rclrs` transport for capability/task/proof topics

**Labels:** `Stellar Wave`, `area: ros`, `complexity: high`
**Points:** 200

### Description
Implement the ROS 2 side of the `Transport` trait using `rclrs`: subscribe to
`/robot/capabilities`, receive tasks, and publish proofs. Provide an example
node and a launch file so a robot can be simulated end to end.

### Requirements and context
- Gate behind a `ros` feature so the workspace still builds without ROS.
- Message types must match `docs/messages.md` (W-01).
- Requires a sourced ROS 2 Jazzy environment to build.
- Definition of done: `cargo build -p ros-bridge` succeeds with ROS sourced, and
  an example publishes a capability that the node logs.

### Suggested execution
- Branch: `feat/ros2-rclrs-transport`
- Touch `crates/ros-bridge/src/lib.rs`; add `examples/` and a launch file.

### Implement changes
- `rclrs` transport, example node, launch file, and build docs.

### Test and commit
- Build under ROS 2 Jazzy; paste `cargo build -p ros-bridge` output and a short
  terminal capture of the example running.

### Example commit message
`feat(ros): add rclrs transport for capability/task/proof`

### Guidelines
- Assignment required before starting.
- PR description must include: `Closes #<issue_id>`.

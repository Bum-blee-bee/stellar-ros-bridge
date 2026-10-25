#!/usr/bin/env bash
# Build, optimize, and deploy the TaskEscrow contract to a Stellar network.
#
# Requirements:
#   * Rust with the wasm32v1-none target (the script installs it when rustup is
#     available). Soroban SDK 28 rejects wasm32-unknown-unknown on Rust 1.82+,
#     so wasm32v1-none is the default. Set WASM_TARGET=wasm32-unknown-unknown
#     only for older SDK/toolchain combinations.
#   * wasm-opt from Binaryen (https://github.com/WebAssembly/binaryen/releases).
#   * stellar-cli v25+ (https://developers.stellar.org/docs/tools/cli).
#
# Usage:
#   STELLAR_SECRET=S... scripts/deploy-escrow.sh
#   STELLAR_SOURCE=my-identity scripts/deploy-escrow.sh
#   STELLAR_NETWORK=testnet STELLAR_SECRET=S... scripts/deploy-escrow.sh
#   scripts/deploy-escrow.sh --build-only   # build + optimize, no deployment
#
# The signing key is read from the environment only. It is never written to
# disk, echoed, or baked into the repository. Prefer STELLAR_SOURCE (a name
# stored by `stellar keys generate`) when you do not want the secret to appear
# in the process argument list.

set -euo pipefail

NETWORK="${STELLAR_NETWORK:-testnet}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/contracts/task-escrow/Cargo.toml"
TARGET="${WASM_TARGET:-wasm32v1-none}"
WASM_DIR="$ROOT/contracts/task-escrow/target/$TARGET/release"
WASM="$WASM_DIR/task_escrow.wasm"
OPTIMIZED_WASM="$WASM_DIR/task_escrow.optimized.wasm"
WASM_OPT="${WASM_OPT:-wasm-opt}"
BUILD_ONLY=0

if [[ "${1:-}" == "--build-only" ]]; then
  BUILD_ONLY=1
elif [[ -n "${1:-}" ]]; then
  echo "error: unknown argument: $1" >&2
  exit 2
fi

die() {
  echo "error: $*" >&2
  exit 1
}

command -v cargo >/dev/null 2>&1 || die "cargo is required (install Rust via rustup)"
command -v "$WASM_OPT" >/dev/null 2>&1 || die \
  "wasm-opt is required (install Binaryen and put it on PATH, or set WASM_OPT)"

if command -v rustup >/dev/null 2>&1; then
  if ! rustup target list --installed | grep -qx "$TARGET"; then
    echo "installing Rust target $TARGET"
    rustup target add "$TARGET"
  fi
fi

echo "building TaskEscrow for $TARGET"
cargo build --manifest-path "$MANIFEST" --release --target "$TARGET" --locked

[[ -f "$WASM" ]] || die "expected wasm at $WASM was not produced"

echo "optimizing wasm with $WASM_OPT"
"$WASM_OPT" -Oz --strip-debug "$WASM" -o "$OPTIMIZED_WASM"

if (( BUILD_ONLY )); then
  echo "build-only: skipping deployment"
  echo "artifact: $OPTIMIZED_WASM"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$OPTIMIZED_WASM"
  fi
  exit 0
fi

command -v stellar >/dev/null 2>&1 || die \
  "stellar-cli is required: https://developers.stellar.org/docs/tools/cli"

if [[ -n "${STELLAR_SECRET:-}" ]]; then
  SOURCE="$STELLAR_SECRET"
  echo "using source account from STELLAR_SECRET"
elif [[ -n "${STELLAR_SOURCE:-}" ]]; then
  SOURCE="$STELLAR_SOURCE"
  echo "using stellar-cli identity $STELLAR_SOURCE"
else
  die "set STELLAR_SECRET (S...) or STELLAR_SOURCE (a stellar keys identity); never commit either"
fi

echo "deploying optimized escrow to $NETWORK"
CONTRACT_ID="$(stellar contract deploy \
  --wasm "$OPTIMIZED_WASM" \
  --source-account "$SOURCE" \
  --network "$NETWORK" \
  --optimize=false)"

[[ -n "$CONTRACT_ID" ]] || die "deployment returned no contract id"

echo
echo "TaskEscrow deployed: $CONTRACT_ID"
echo "export TASK_ESCROW_CONTRACT_ID=$CONTRACT_ID"
echo "explorer: https://stellar.expert/explorer/$NETWORK/contract/$CONTRACT_ID"

<#
.SYNOPSIS
Build, optimize, and deploy the TaskEscrow contract to a Stellar network.

.DESCRIPTION
Requires Rust with the wasm32v1-none target, wasm-opt from Binaryen, and
stellar-cli v25+. Soroban SDK 28 rejects wasm32-unknown-unknown on Rust 1.82+,
so wasm32v1-none is the default; set WASM_TARGET only for older SDK/toolchain
combinations. The signing key is read from STELLAR_SECRET (or a stellar-cli
identity named by STELLAR_SOURCE) and is never written to disk or printed.

.PARAMETER BuildOnly
Build and optimize the wasm without deploying (useful in CI).

.EXAMPLE
$env:STELLAR_SECRET = "S..."; ./scripts/deploy-escrow.ps1

.EXAMPLE
$env:STELLAR_SOURCE = "my-identity"; ./scripts/deploy-escrow.ps1 -Network testnet

.EXAMPLE
./scripts/deploy-escrow.ps1 -BuildOnly
#>
[CmdletBinding()]
param(
    [string]$Network = $(if ($env:STELLAR_NETWORK) { $env:STELLAR_NETWORK } else { "testnet" }),
    [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $Root "contracts/task-escrow/Cargo.toml"
$Target = if ($env:WASM_TARGET) { $env:WASM_TARGET } else { "wasm32v1-none" }
$WasmDir = Join-Path $Root "contracts/task-escrow/target/$Target/release"
$Wasm = Join-Path $WasmDir "task_escrow.wasm"
$OptimizedWasm = Join-Path $WasmDir "task_escrow.optimized.wasm"
$WasmOpt = if ($env:WASM_OPT) { $env:WASM_OPT } else { "wasm-opt" }

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

$Cargo = Get-Command cargo -ErrorAction SilentlyContinue
if (-not $Cargo) { Fail "cargo is required (install Rust via rustup)" }

$WasmOptCommand = Get-Command $WasmOpt -ErrorAction SilentlyContinue
if (-not $WasmOptCommand) {
    Fail "wasm-opt is required (install Binaryen and put it on PATH, or set WASM_OPT)"
}

$Rustup = Get-Command rustup -ErrorAction SilentlyContinue
if ($Rustup) {
    $installedTargets = & rustup target list --installed
    if ($LASTEXITCODE -ne 0) { Fail "rustup target list failed" }
    if ($installedTargets -notcontains $Target) {
        Write-Host "installing Rust target $Target"
        & rustup target add $Target
        if ($LASTEXITCODE -ne 0) { Fail "failed to install Rust target $Target" }
    }
}

# soroban-sdk 28 needs this build-system flag; the CI contract job sets it too.
$env:SOROBAN_SDK_BUILD_SYSTEM_SUPPORTS_SPEC_SHAKING_V2 = "1"

Write-Host "building TaskEscrow for $Target"
& cargo build --manifest-path $Manifest --release --target $Target --locked
if ($LASTEXITCODE -ne 0) { Fail "cargo build failed" }

if (-not (Test-Path -LiteralPath $Wasm)) {
    Fail "expected wasm at $Wasm was not produced"
}

Write-Host "optimizing wasm with $WasmOpt"
& $WasmOptCommand.Source -Oz --strip-debug $Wasm -o $OptimizedWasm
if ($LASTEXITCODE -ne 0) { Fail "wasm-opt failed" }

if ($BuildOnly) {
    Write-Host "build-only: skipping deployment"
    Write-Host "artifact: $OptimizedWasm"
    Get-FileHash -Algorithm SHA256 -LiteralPath $OptimizedWasm |
        Select-Object -ExpandProperty Hash
    exit 0
}

$Stellar = Get-Command stellar -ErrorAction SilentlyContinue
if (-not $Stellar) {
    Fail "stellar-cli is required: https://developers.stellar.org/docs/tools/cli"
}

if ($env:STELLAR_SECRET) {
    $Source = $env:STELLAR_SECRET
    Write-Host "using source account from STELLAR_SECRET"
} elseif ($env:STELLAR_SOURCE) {
    $Source = $env:STELLAR_SOURCE
    Write-Host "using stellar-cli identity $($env:STELLAR_SOURCE)"
} else {
    Fail "set STELLAR_SECRET (S...) or STELLAR_SOURCE (a stellar keys identity); never commit either"
}

Write-Host "deploying optimized escrow to $Network"
$contractId = & stellar contract deploy `
    --wasm $OptimizedWasm `
    --source-account $Source `
    --network $Network `
    --optimize=false | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { Fail "contract deployment failed" }

$contractId = "$contractId".Trim()
if (-not $contractId) { Fail "deployment returned no contract id" }

Write-Host ""
Write-Host "TaskEscrow deployed: $contractId"
Write-Host "`$env:TASK_ESCROW_CONTRACT_ID = `"$contractId`""
Write-Host "explorer: https://stellar.expert/explorer/$Network/contract/$contractId"
